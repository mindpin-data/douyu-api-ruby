class DouyuDanmuRecord
  include Mongoid::Document
  include Mongoid::Timestamps

  field :data
  field :raw
end