namespace :db do
  namespace :update do
    desc "Update development database from production dump (only matching tables)"
    task from_production: :environment do
      require 'open-uri'
      require 'fileutils'
      
      # URL дампа из S3
      DUMP_URL = "https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23/backups/mark_production_2025-11-07T00:00:00.dump"
      DUMP_FILE = Rails.root.join("tmp", "production_dump.dump")
      TEMP_DB = "mark_production_temp_#{Time.now.to_i}"
      
      # Найти путь к PostgreSQL утилитам
      PG_BIN = if File.exist?("/opt/homebrew/opt/postgresql@15/bin/pg_restore")
        "/opt/homebrew/opt/postgresql@15/bin"
      elsif File.exist?("/usr/local/opt/postgresql@15/bin/pg_restore")
        "/usr/local/opt/postgresql@15/bin"
      else
        # Попробовать найти в PATH
        pg_restore_path = `which pg_restore 2>/dev/null`.strip
        if pg_restore_path.empty?
          nil
        else
          File.dirname(pg_restore_path)
        end
      end
      
      unless PG_BIN && File.exist?(File.join(PG_BIN, "pg_restore"))
        raise "PostgreSQL client tools not found. Please install PostgreSQL or add pg_restore to PATH."
      end
      
      PG_RESTORE = File.join(PG_BIN, "pg_restore")
      PSQL = File.join(PG_BIN, "psql")
      
      puts "📥 Updating development database from production dump..."
      puts "🔗 Source: #{DUMP_URL}"
      
      # Создать директорию для временных файлов
      FileUtils.mkdir_p(Rails.root.join("tmp"))
      
      # Скачать дамп если его нет локально
      unless File.exist?(DUMP_FILE)
        puts "📥 Downloading dump file..."
        File.open(DUMP_FILE, 'wb') do |file|
          URI.open(DUMP_URL) do |remote_file|
            file.write(remote_file.read)
          end
        end
        puts "✅ Dump downloaded: #{DUMP_FILE}"
      else
        puts "✅ Using existing dump file: #{DUMP_FILE}"
      end
      
      # Получить список таблиц из development базы
      dev_tables = ActiveRecord::Base.connection.tables.reject do |table|
        table.start_with?('schema_migrations', 'ar_internal_metadata')
      end.sort
      
      puts "\n📊 Found #{dev_tables.count} tables in development database:"
      dev_tables.each { |t| puts "  - #{t}" }
      
      # Сохранить подключение к development
      dev_conn = ActiveRecord::Base.connection
      
      # Создать временную базу для импорта дампа
      puts "\n🔧 Creating temporary database: #{TEMP_DB}"
      dev_conn.execute("CREATE DATABASE #{TEMP_DB}")
      
      begin
        # Импортировать дамп во временную базу
        puts "📥 Importing dump to temporary database..."
        unless File.exist?(PG_RESTORE)
          raise "pg_restore not found at #{PG_RESTORE}. Please install PostgreSQL client tools."
        end
        system("PGPASSWORD=#{ENV['PGPASSWORD'] || 'postgres'} #{PG_RESTORE} -d #{TEMP_DB} --verbose #{DUMP_FILE}") || raise("Failed to import dump")
        
        # Получить список таблиц из production дампа (через временную базу)
        # Получить конфигурацию из текущего подключения
        current_config = ActiveRecord::Base.connection_db_config.configuration_hash.dup
        temp_config = current_config.merge(database: TEMP_DB)
        ActiveRecord::Base.establish_connection(temp_config)
        temp_conn = ActiveRecord::Base.connection
        
        prod_tables = temp_conn.tables.reject do |table|
          table.start_with?('schema_migrations', 'ar_internal_metadata')
        end.sort
        
        puts "\n📊 Found #{prod_tables.count} tables in production dump:"
        prod_tables.each { |t| puts "  - #{t}" }
        
        # Найти совпадающие таблицы
        matching_tables = dev_tables & prod_tables
        missing_tables = dev_tables - prod_tables
        extra_tables = prod_tables - dev_tables
        
        puts "\n🔍 Analysis:"
        puts "  ✅ Matching tables: #{matching_tables.count}"
        puts "  ⚠️  Missing in production: #{missing_tables.count}" if missing_tables.any?
        puts "  ℹ️  Extra in production: #{extra_tables.count}" if extra_tables.any?
        
        if matching_tables.empty?
          puts "\n❌ No matching tables found!"
          next
        end
        
        # Подтверждение
        puts "\n⚠️  This will UPDATE data in the following tables:"
        matching_tables.each { |t| puts "  - #{t}" }
        
        # Проверка на автоматическое подтверждение через переменную окружения
        if ENV['AUTO_CONFIRM'] == 'true'
          puts "\n✅ Auto-confirmed (AUTO_CONFIRM=true)"
        else
          print "\nContinue? (y/N): "
          input = STDIN.gets
          unless input && input.chomp.downcase == 'y'
            puts "❌ Aborted"
            next
          end
        end
        
        # Переключиться обратно на development для обновления данных
        ActiveRecord::Base.establish_connection(:development)
        dev_conn = ActiveRecord::Base.connection
        
        # Определить порядок обновления таблиц (с учетом зависимостей)
        # Сначала обновляем таблицы без зависимостей, потом зависимые
        table_order = []
        remaining = matching_tables.dup
        
        # Найти таблицы без внешних ключей (или с минимальными зависимостями)
        while remaining.any?
          remaining.each do |table|
            # Проверить, есть ли зависимости от других таблиц в списке
            fks = temp_conn.foreign_keys(table)
            dependencies = fks.map { |fk| fk.to_table }.select { |t| matching_tables.include?(t) && !table_order.include?(t) }
            
            if dependencies.empty?
              table_order << table
              remaining.delete(table)
            end
          end
          
          # Если не удалось найти таблицы без зависимостей, добавить оставшиеся
          if remaining.any? && table_order.count == 0
            table_order.concat(remaining)
            remaining.clear
          end
        end
        
        # Временно отключить foreign key проверки
        dev_conn.execute("SET session_replication_role = 'replica'")
        
        table_order.each do |table|
          puts "\n🔄 Updating table: #{table}"
          
          begin
            # Получить количество записей в production
            count_result = temp_conn.execute("SELECT COUNT(*) as count FROM #{table}")
            count = count_result.first['count'].to_i
            
            if count == 0
              puts "  ⚠️  Table is empty in production, truncating local table"
              dev_conn.execute("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE")
              next
            end
            
            # Получить колонки таблицы (только те, что есть в обеих базах)
            prod_columns = temp_conn.columns(table).map(&:name)
            dev_columns = dev_conn.columns(table).map(&:name)
            common_columns = prod_columns & dev_columns
            
            if common_columns.empty?
              puts "  ⚠️  No common columns found, skipping"
              next
            end
            
            # Очистить таблицу в development
            dev_conn.execute("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE")
            
            # Копировать данные через COPY (самый быстрый способ)
            # Используем временный файл для передачи данных
            temp_file = Rails.root.join("tmp", "#{table}_#{Time.now.to_i}.csv")
            
            # Экспорт из production
            unless File.exist?(PSQL)
              raise "psql not found at #{PSQL}. Please install PostgreSQL client tools."
            end
            export_cmd = "PGPASSWORD=#{ENV['PGPASSWORD'] || 'postgres'} #{PSQL} -d #{TEMP_DB} -U postgres -c \"\\COPY (SELECT #{common_columns.join(', ')} FROM #{table}) TO '#{temp_file}' WITH CSV\""
            unless system(export_cmd)
              raise "Failed to export #{table}"
            end
            
            # Импорт в development
            import_cmd = "PGPASSWORD=#{ENV['PGPASSWORD'] || 'postgres'} #{PSQL} -d mark_development -U postgres -c \"\\COPY #{table} (#{common_columns.join(', ')}) FROM '#{temp_file}' WITH CSV\""
            unless system(import_cmd)
              raise "Failed to import #{table}"
            end
            
            # Удалить временный файл
            File.delete(temp_file) if File.exist?(temp_file)
            
            # Проверить количество записей после импорта
            final_count = dev_conn.execute("SELECT COUNT(*) as count FROM #{table}").first['count'].to_i
            puts "  ✅ Updated #{final_count} records (#{common_columns.count} columns)"
          rescue => e
            puts "  ❌ Error updating #{table}: #{e.message}"
            puts "  #{e.backtrace.first(3).join("\n  ")}"
          end
        end
        
        # Включить обратно foreign key проверки
        dev_conn.execute("SET session_replication_role = 'origin'")
        
        puts "\n✅ Update completed!"
        puts "📊 Updated #{matching_tables.count} tables"
        
      ensure
        # Закрыть подключение к временной базе и переподключиться к development
        begin
          if ActiveRecord::Base.connected? && ActiveRecord::Base.connection.current_database == TEMP_DB
            ActiveRecord::Base.connection.disconnect!
          end
        rescue
          # Игнорировать ошибки при отключении
        end
        
        ActiveRecord::Base.establish_connection(:development)
        
        # Удалить временную базу (нужно подключиться к другой базе, например postgres)
        puts "\n🧹 Cleaning up temporary database..."
        begin
          postgres_config = ActiveRecord::Base.connection_db_config.configuration_hash.dup.merge(database: 'postgres')
          ActiveRecord::Base.establish_connection(postgres_config)
          ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS #{TEMP_DB}")
          ActiveRecord::Base.establish_connection(:development)
        rescue => e
          puts "  ⚠️  Warning: Could not drop temporary database: #{e.message}"
          puts "  You may need to manually drop it: DROP DATABASE #{TEMP_DB};"
        end
      end
    end
  end
end

