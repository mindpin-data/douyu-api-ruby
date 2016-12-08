require 'rubygems'

require 'bundler/setup' 
Bundler.require

require 'socket'
require 'logger'

require_relative './douyu-socket-message'
require_relative './danmu-record'

module Logging
  def logger
    @logger ||= Logger.new($stdout)
  end
end

class DouyuDanmuCollector
  include Logging

  SERVER = 'openbarrage.douyutv.com'
  PORT = 8601

  def initialize(roomid)
    @roomid = roomid
  end

  def connect
    self.init
    self.do_keeplive
    self.get_danmu
  end

  def init
    @socket.close if @socket
    @socket = TCPSocket.new SERVER, PORT
    logger.info '初始化 socket'

    self.login
    self.joingroup
  end

  # 登录
  def login
    logger.info '登录'
    send_message "type@=loginreq/roomid@=#{@roomid}/", true
  end

  # 加入弹幕组
  def joingroup
    logger.info "加入弹幕组，开始接收弹幕，直播间：#{@roomid}"
    send_message "type@=joingroup/rid@=#{@roomid}/gid@=-9999/", true
  end

  # 在另一个线程保持心跳
  def do_keeplive
    Thread.new do
      loop do
        puts "--> KeepAlive"
        sleep 40

        self.send_message "type@=keeplive/tick@=#{Time.now.to_i}/"
      end
    end
  end

  def get_danmu
    content = ''
    last_save_time = Time.now

    loop do
      delta = @socket.recv(1024)
      content = content + delta

      # 五分钟无响应则重连
      if Time.now - last_save_time > 300
        content = ''
        self.init
      end

      if content[-1] == "\x00"
        msg = DouyuSocketMessageContent.new(content)
        msg.save
        last_save_time = Time.now

        content = ''
        puts msg
        self.init if msg.type == 'error'
      end
    end
  end

  private

    def send_message(content, show=false)
      puts content if show
      @socket.write DouyuSocketMessage.new(content).to_s
    end
end

Mongoid.load!("mongoid.yml", :development)

ddc = DouyuDanmuCollector.new ARGV[0]
ddc.connect