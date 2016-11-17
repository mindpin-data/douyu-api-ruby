require 'uri'
require 'net/http'
require 'json'

uri = URI('http://api.douyutv.com/api/v1/live/lol')
string = Net::HTTP.get(uri)
data = JSON.parse string

p data