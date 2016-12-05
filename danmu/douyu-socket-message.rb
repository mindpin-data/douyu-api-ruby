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

class DouyuSocketMessageContent
  def initialize(content)
    @raw = content
    @content = content.force_encoding('UTF-8')[content.index('type@=')..-2]
  end

  def data
    @data ||= begin
      h = {}
      @content.split('/').each do |x|
        key, value = x.split('@=')
        h[key] = value.gsub('@S', '/').gsub('@A', '@') if value
      end
      h
    rescue
      puts @raw
      {}
    end
  end

  def type
    @type ||= self.data['type']
  end

  def to_s
    case type
    when 'chatmsg'
      name = align_left_str(data['nn'], 20, ' ')
      lv = data['level']
      "[弹幕] #{name}\t<lv:#{lv}>\t #{Time.now}：#{data['txt']}"
    else
      "[#{type}] #{data}"
    end
  end

  def save
    record = DouyuDanmuRecord.create({
      data: self.data,
      raw: @content
    })
  rescue
    puts '保存失败'
  end

  # 抄来的，在文本后填充字符，考虑中文
  def align_left_str(raw_str, max_length, filled_chr)
    my_length = 0
    for i in 0...raw_str.size
      if raw_str[i].ord > 127 || raw_str[i].ord <=0
        my_length += 1
      end
      my_length += 1
    end
    if (max_length - my_length) > 0
      raw_str + filled_chr * ( max_length - my_length )
    else
      raw_str
    end
  end
end