class SwatchSetting < ApplicationRecord
  validates :setting_key, presence: true, uniqueness: true

  def self.get(key, default_value = nil)
    setting = find_by(setting_key: key)
    return default_value unless setting

    case setting.setting_type
    when 'json' then JSON.parse(setting.setting_value) rescue default_value
    when 'boolean' then setting.setting_value == 'true'
    when 'integer' then setting.setting_value.to_i
    else setting.setting_value
    end
  end

  def self.set(key, value, type = 'string')
    serialized = case type
                 when 'json' then value.to_json
                 when 'boolean' then value.to_s
                 else value.to_s
                 end
    record = find_or_initialize_by(setting_key: key)
    record.update!(setting_value: serialized, setting_type: type)
  end
end
