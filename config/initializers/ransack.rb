Ransack.configure do |config|

    config.add_predicate 'datebegin',
    arel_predicate: 'gteq',
    formatter: proc { |v| v.in_time_zone("Moscow").to_date.beginning_of_day },
    validator: proc { |v| v.present? },
    type: :date

    config.add_predicate 'dateend',
    arel_predicate: 'lteq',
    formatter: proc { |v| v.in_time_zone("Moscow").to_date.end_of_day },
    validator: proc { |v| v.present? },
    type: :date

end