class ListItem < ApplicationRecord
  belongs_to :list
  belongs_to :item, polymorphic: true
  belongs_to :client


end
