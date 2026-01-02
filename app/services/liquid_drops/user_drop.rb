module LiquidDrops
  class UserDrop < ::Liquid::Drop
    def initialize(user, account: nil)
      @user = user
      @account = account
    end

    def email_address
      @user.respond_to?(:email_address) ? @user.email_address : nil
    end

    def role_in_account
      # Получаем роль пользователя в конкретном аккаунте
      return nil unless @user.respond_to?(:account_users)
      
      if @account
        # Если передан account, ищем роль в этом аккаунте
        account_user = @user.account_users.find_by(account: @account)
        return account_user&.role
      end
      
      # Иначе возвращаем первую роль (для обратной совместимости)
      account_user = @user.account_users.first
      account_user&.role
    end
  end
end

