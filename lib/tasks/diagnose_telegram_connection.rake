namespace :telegram do
  desc "Diagnose Telegram MTProto connection issues"
  task diagnose_connection: :environment do
    require "socket"
    require "timeout"
    
    puts "🔍 Telegram Connection Diagnostics"
    puts "=" * 60
    
    # Test basic TCP connection
    servers = [
      { name: "Production DC2", ip: "149.154.167.51", port: 443 },
      { name: "Test DC", ip: "149.154.167.40", port: 443 },
      { name: "Production DC2 Alt", ip: "149.154.167.50", port: 443 }
    ]
    
    servers.each do |server|
      puts "\n📡 Testing #{server[:name]} (#{server[:ip]}:#{server[:port]})..."
      
      begin
        Timeout.timeout(10) do
          socket = TCPSocket.new(server[:ip], server[:port])
          socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
          
          puts "  ✅ TCP connection successful"
          
          # Try to send a simple packet (req_pq_multi header)
          # req_pq_multi#be7e8ef1 nonce:int128
          # TCP FULL format: [length(4)][seq(4)][auth_key_id(8)][msg_id(8)][length(4)][data...]
          
          nonce_bytes = SecureRandom.random_bytes(16)
          req_pq = [0xbe7e8ef1].pack('L<') + nonce_bytes
          
          # TCP FULL packet
          msg_id = (Time.now.to_f * 4294967296).to_i
          packet_len = 8 + 8 + 4 + req_pq.length  # auth_key_id + msg_id + length + data
          packet = [packet_len, 0].pack('i<i<') +  # length, seq
                   [0, 0].pack('q<q<') +            # auth_key_id = 0, msg_id
                   [req_pq.length].pack('i<') +     # length
                   req_pq
          
          socket.write(packet)
          puts "  ✅ Sent req_pq_multi packet (#{packet.length} bytes)"
          
          # Try to read response
          Timeout.timeout(5) do
            header = socket.read(8)  # length + seq
            if header && header.length == 8
              len, seq = header.unpack('i<i<')
              puts "  ✅ Received response header: len=#{len}, seq=#{seq}"
              
              if len < 0
                puts "  ⚠️  Server returned error code: #{len} (AUTH_KEY_UNREGISTERED)" if len == -404
                puts "  ⚠️  Server returned error code: #{len}"
              elsif len > 0 && len < 10000
                body = socket.read(len - 8)
                if body
                  puts "  ✅ Received response body (#{body.length} bytes)"
                  puts "  📦 Response HEX: #{body.unpack('H*')[0][0..100]}..."
                else
                  puts "  ❌ Failed to read response body"
                end
              else
                puts "  ⚠️  Invalid response length: #{len}"
              end
            else
              puts "  ❌ Failed to read response header (got #{header&.length || 0} bytes)"
            end
          end
          
          socket.close
        end
      rescue Timeout::Error
        puts "  ❌ Connection timeout"
      rescue => e
        puts "  ❌ Connection failed: #{e.class}: #{e.message}"
      end
    end
    
    puts "\n" + "=" * 60
    puts "✅ Diagnostics complete"
  end
end
