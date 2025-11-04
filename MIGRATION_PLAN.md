# План миграции на many-to-many связь Account <-> User

## Текущая структура
- `User` belongs_to `Account` (один аккаунт на пользователя)
- `User` имеет поле `role` (enum: admin, member)
- `Account` has_many `users`

## Целевая структура
- `User` has_many `account_users`
- `Account` has_many `account_users`
- `AccountUser` (join table): `user_id`, `account_id`, `role` (enum: admin, member)
- Пользователь может быть в нескольких аккаунтах с разными ролями

---

## Этап 1: Создание соединительной таблицы

### 1.1 Миграция: Создание таблицы `account_users`
```ruby
create_table :account_users do |t|
  t.references :user, null: false, foreign_key: true
  t.references :account, null: false, foreign_key: true
  t.string :role, null: false, default: "member"
  t.timestamps
end

add_index :account_users, [:user_id, :account_id], unique: true
add_index :account_users, :role
```

### 1.2 Миграция: Перенос данных
- Для каждого существующего `User`:
  - Создать `AccountUser` с `user_id`, `account_id` (из `user.account_id`), `role` (из `user.role`)
  - Сохранить даты создания/обновления из `User`

### 1.3 Миграция: Удаление старых полей
- Удалить колонку `account_id` из таблицы `users`
- Удалить колонку `role` из таблицы `users`

---

## Этап 2: Обновление моделей

### 2.1 Создать модель `AccountUser`
```ruby
class AccountUser < ApplicationRecord
  belongs_to :user
  belongs_to :account
  
  enum :role, { admin: "admin", member: "member" }, default: "member"
  
  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :account_id }
  
  validate :only_one_admin_per_account
end
```

### 2.2 Обновить модель `User`
```ruby
# Убрать:
- belongs_to :account
- enum :role
- validates :email_address, uniqueness: { scope: :account_id } → изменить на глобальную уникальность
- validate :only_one_admin_per_account
- after_create_commit/after_update_commit/after_destroy_commit (обновить на account_users)

# Добавить:
+ has_many :account_users, dependent: :destroy
+ has_many :accounts, through: :account_users

# Вспомогательные методы:
+ def role_in_account(account)
+   account_users.find_by(account: account)&.role
+ end

+ def admin_in_account?(account)
+   role_in_account(account) == 'admin'
+ end

+ def admin_in_any_account?
+   account_users.where(role: 'admin').exists?
+ end
```

### 2.3 Обновить модель `Account`
```ruby
# Изменить:
- has_many :users, dependent: :destroy
+ has_many :account_users, dependent: :destroy
+ has_many :users, through: :account_users
```

### 2.4 Убрать `AccountScoped` из модели `User`
- `User` больше не имеет прямого `account_id`, поэтому `default_scope` не работает
- Удалить `include AccountScoped` из модели `User`
- Все запросы к пользователям должны быть явно через `account.users` или `account.account_users`

---

## Этап 3: Обновление проверок прав доступа

### 3.1 `ApplicationController#ensure_user_in_current_account`
- Заменить проверку `Current.user.account_id != Current.account.id`
- На проверку: `Current.user.accounts.include?(Current.account)`

### 3.2 `UsersController#ensure_admin`
- Заменить `Current.user&.admin?`
- На: `Current.user&.admin_in_account?(current_account) || Current.user&.account&.admin?`

### 3.3 `AccountsController#ensure_super_admin_account`
- Оставить проверку `account&.admin?` (супер-админ аккаунт)

### 3.4 Все места где используется `user.admin?` или `user.role`
- Заменить на проверку роли в конкретном аккаунте через `AccountUser`

---

## Этап 4: Обновление контроллеров

### 4.1 `UsersController`
- `index`: `current_account.users` (через account_users) - не меняется
- `new`: `current_account.users.new` → изменить логику создания через account_users
- `create`: Создание через `AccountUser` вместо прямого создания `User`
- `set_user`: Использовать `current_account.account_users.find_by(user_id: params[:id])`

### 4.2 `AccountsController`
- `new_user`, `create_user`, `edit_user`, `update_user`: Адаптировать под `AccountUser`

### 4.3 Обновить все запросы к пользователям
- `account.users.where(...)` → `account.account_users.joins(:user).where(...)`

---

## Этап 5: Обновление форм и views

### 5.1 `users/_form_data.html.erb`
- Изменить поле `role` - оно теперь относится к `AccountUser`, а не к `User`
- Для создания пользователя в аккаунте создавать `AccountUser` с ролью

### 5.2 `accounts/_user.html.erb`
- Показывать роль из `account_user.role` вместо `user.role`

### 5.3 Все места где отображается `user.role`
- Заменить на `user.role_in_account(account)` или `account_user.role`

---

## Этап 6: Обновление валидаций

### 6.1 Уникальность email
- Изменить с `uniqueness: { scope: :account_id }` на глобальную уникальность
- Email должен быть уникальным глобально (уже есть индекс в БД)

### 6.2 Валидация "только один админ на аккаунт"
- Переместить из `User` в `AccountUser`
- Проверять при создании/обновлении `AccountUser` с ролью `admin`

---

## Этап 7: Обновление broadcast/callbacks

### 7.1 User callbacks
- `after_create_commit`, `after_update_commit`, `after_destroy_commit` в модели `User`
- Переместить/переработать для работы с `AccountUser`

### 7.2 Добавить callbacks в `AccountUser`
- Broadcast обновлений списка пользователей аккаунта

---

## Этап 8: Обновление логики работы с текущим аккаунтом

### 8.1 `ApplicationController#set_current_account`
- Обновить логику определения текущего аккаунта
- Если пользователь в нескольких аккаунтах:
  - Приоритет: аккаунт из `params[:account_id]`
  - Если нет: первый аккаунт пользователя (`Current.user.accounts.first`)
  - Если пользователь супер-админ: первый админ-аккаунт

### 8.2 `SessionsController#after_authentication_url`
- Заменить `Current.session.user.account_id`
- На: `Current.user.accounts.first&.id` или первый доступный аккаунт

### 8.3 `SessionsController#new`
- Заменить `Current.session.user.account_id`
- На: `Current.user.accounts.first&.id`

### 8.4 Убрать `AccountScoped` из модели `User`
- `User` больше не имеет прямого `account_id`, поэтому `AccountScoped` не применим
- Удалить `include AccountScoped` из `User`

---

## Этап 9: Обновление всех запросов к `users` для удаления зависимостей от `account_id` и `role`

### 9.1 Проверка кодовой базы
- Найти все места, где используются `user.account_id`, `user.role`, `user.admin?`
- Заменить на использование `AccountUser` или методов-хелперов
- Убедиться, что нет прямых запросов к удаляемым полям

---

## Этап 10: Обновление seeds.rb
- Обновить создание тестовых данных с учетом новой структуры

---

## Порядок выполнения миграций:

1. ✅ Создать модель `AccountUser`
2. ✅ Создать миграцию для таблицы `account_users`
3. ✅ Создать миграцию для переноса данных
4. ✅ Создать миграцию для удаления `account_id` и `role` из `users`
5. ✅ Обновить модели (`User`, `Account`, `AccountUser`)
6. ✅ Обновить контроллеры и проверки прав
7. ✅ Обновить views
8. ✅ Обновить валидации
9. ✅ Обновить callbacks/broadcasts
10. ✅ Обновить все запросы, удалив зависимости от старых полей
11. ✅ Тестирование
12. ✅ Запуск миграций

---

## Важные моменты для проверки:

1. **Безопасность данных**: Убедиться, что все существующие пользователи получат записи в `account_users`
2. **Уникальность email**: Изменить валидацию на глобальную уникальность (уже есть уникальный индекс в БД)
3. **Проверки прав**: Все проверки должны учитывать роль в конкретном аккаунте через `AccountUser`
4. **Удаление старых полей**: Удалить `account_id` и `role` из `users` сразу после переноса данных
5. **Session/Current.user**: Обновить логику определения текущего аккаунта для пользователя
6. **AccountScoped**: Убрать из `User`, так как пользователь больше не имеет прямого `account_id`
7. **Default account**: Определить логику выбора аккаунта по умолчанию после входа (первый аккаунт? приоритетный?)
8. **Broadcasts**: Обновить Turbo Stream broadcasts для работы с `AccountUser` вместо прямых связей

