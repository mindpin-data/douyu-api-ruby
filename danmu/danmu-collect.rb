require 'socket'
require 'logger'

module Logging
  def logger
    @logger ||= Logger.new($stdout)
  end
end

class DouyuSocketMessage
  # 向斗鱼发送的消息
  # 1. 消息长度，四个字节（整条消息，包括后续部分）（相当于原消息 + 4 + 2 + 2 + 1 个字节）
  # 2. 消息长度，同第一部分
  # 3. 请求代码，发送给斗鱼时是 689，斗鱼返回时是 690，两个字节
  # 4. 加密字段 0，保留字段 0，两个字节
  # 5. 数据内容
  # 6. 末尾字节 '\0'

  # 四字节 pack('L')
  # 两字节 pack('S')
  # 一字节 pack('C')

  def initialize(content)
    # http://ruby-doc.org/core-2.3.3/Array.html#method-i-pack

    @length = [content.length + 9].pack('L')
    @code = [689].pack('S')
    @secret = [0].pack('C') + [0].pack('C')
    @content = content
    @end = [0].pack('C')
  end

  def to_s
    @length + @length + @code + @secret + @content + @end
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
    @socket = TCPSocket.new SERVER, PORT
    logger.info '初始化 socket'

    self.login
    self.joingroup
    self.do_keeplive
    self.get_danmu
  end

  # 登录
  def login
    data = "type@=loginreq/roomid@=#{@roomid}/"
    logger.info '登录'
    logger.info data
    @socket.write DouyuSocketMessage.new(data).to_s
    res = @socket.recv(4000)
    logger.info '登录成功'
    logger.info res
  end

  # 加入弹幕组
  def joingroup
    data = "type@=joingroup/rid@=#{@roomid}/gid@=-9999/"
    logger.info '加入弹幕组'
    logger.info data
    @socket.write DouyuSocketMessage.new(data).to_s
    logger.info '加入弹幕组成功，开始接收弹幕'
  end

  def get_danmu
    content = ''

    loop {
      res = @socket.recv(4000)
      content = content + res

      if res[-1] == "\x00"
        content = content.force_encoding('UTF-8')
        content = content[content.index('type@=')..-2]
        p content
        content = ''
      end
    }
  end

  # 在另一个线程保持心跳
  def do_keeplive
    Thread.new do
      loop do
        puts "--> KeepAlive"
        sleep 40

        data = "type@=keeplive/tick@=#{Time.now.to_i}/"
        @socket.write DouyuSocketMessage.new(data).to_s
      end
    end
  end
end

ddc = DouyuDanmuCollector.new 110174
ddc.connect