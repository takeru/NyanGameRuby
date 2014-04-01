include Cocos2d
include CocosDenshion

class Node
  @@wrap_objects = {}
  @@cc_object_id = 0
  attr_reader :cc_object

  def initialize(*args)
    @cc_class_name ||= 'CC' + self.class.to_s
    @cc_class = Cocos2d.const_get(@cc_class_name)
    @cc_object = @cc_class.create(*args)
    @@cc_object_id += 1
    @cc_object.m_nLuaID = @@cc_object_id
    @@wrap_objects[@cc_object.dataptr] = self
  end

  def self._removeScriptObject(obj)
    @@wrap_objects.delete(obj.dataptr)
  end

  def method_missing(method, *args, &block)
    args = args.map do |arg|
      if arg.kind_of?(Node)
        arg.cc_object
      else
        arg
      end
    end

    ret = @cc_object.send(method, *args, &block)

    if ret.kind_of?(Cocos2d::CCNode)
      if @@wrap_objects[ret.dataptr]
        ret = @@wrap_objects[ret.dataptr]
      end
    end

    return ret
  end
end

Cocos2d::Callback.removeScriptObject = proc do |obj|
  Node._removeScriptObject(obj)
end

class Sprite < Node
end

class Layer < Node
end

class Scene < Node
end



class Block < Sprite
  attr_reader :color
  def initialize(color)
    @cc_class_name = 'CCSprite'
    super(color.to_s + ".png")

    @color = color
  end
  def to_s
    super + " #{color} #{getTag}"
  end
end

class NyanGame
  attr_reader :zorder, :tag
  COLORS = [:red, :blue, :yellow, :green, :gray]
  BLOCK_MAX_X = 8
  BLOCK_MAX_Y = 8
  MP3_REMOVE_BLOCK = "removeBlock.mp3"

  def initialize
    @win_size = CCDirector.sharedDirector.getWinSize
    @zorder = {
      :bg    =>    0,
      :block =>  100,
    }
    @tag    = {
      :bg         =>    1,
      :block      =>    2,
      :block_base => 1000,
    }

    @animating = false
    @score     = 0
  end

  def scene
    unless @scene
      @layer = Layer.new

      @touchBeginPoint = nil
      @layer.registerScriptTouchHandler do |eventType, touch|
        case eventType
        when CCTOUCHBEGAN
          onTouchBegan(touch)
        when CCTOUCHMOVED
          onTouchMoved(touch)
        when CCTOUCHENDED
          onTouchEnded(touch)
        when CCTOUCHCANCELLED
          onTouchCanceled(touch)
        else
          raise "unknown eventType=#{eventType}"
        end
      end
      @layer.setTouchMode(KCCTouchesOneByOne)
      @layer.setTouchEnabled(true)

      @bg = Sprite.new("background.png")
      @bg.setPosition(@win_size.width/2, @win_size.height/2)
      @layer.addChild(@bg, zorder[:bg], tag[:bg])

      @scene = Scene.new
      @scene.addChild(@layer)

      @block = Block.new(:red)
      @block_size = @block.getContentSize.height

      if "demo"
        @block.setPosition(@win_size.width/2, @win_size.height/2)
        @bg.addChild(@block, zorder[:block], tag[:block])
      end

      _createBlocks

      SimpleAudioEngine.sharedEngine.preloadEffect(MP3_REMOVE_BLOCK)
    end
    @scene
  end

  def blockCCPoint(x, y)
    offsetX = @bg.getContentSize.width  * 0.168
    offsetY = @bg.getContentSize.height * 0.029
    return ccp(
      (x+0.5) * @block_size + offsetX,
      (y+0.5) * @block_size + offsetY
    )
  end

  def blockTag(x, y)
    tag[:block_base] + x * 100 + y
  end

  def _createBlocks
    (0...BLOCK_MAX_X).each do |x|
      (0...BLOCK_MAX_Y).each do |y|
        color = COLORS[rand(COLORS.size)]
        block = Block.new(color)
        block.setPosition(blockCCPoint(x,y))
        @bg.addChild(block, zorder[:block], blockTag(x,y))
      end
    end
  end

  def onTouchBegan(touch)
    glPt = CCDirector.sharedDirector.convertToGL(touch.getLocationInView)

    point = @bg.convertTouchToNodeSpace(touch)
    puts("onTouchBegan: #{point.x},#{point.y} GL=(#{glPt.x},#{glPt.y})")
    @touchBeginPoint = {:x=>point.x, :y=>point.y}

    return !@animating
  end

  def onTouchMoved(touch)
    point = @bg.convertTouchToNodeSpace(touch)
    puts("onTouchMoved: #{point.x},#{point.y}")
    if @touchBeginPoint
      pos = @block.getPosition
      @block.setPosition(
        pos.x + (point.x - @touchBeginPoint[:x]),
        pos.y + (point.y - @touchBeginPoint[:y])
      )
      @touchBeginPoint = {:x=>point.x, :y=>point.y}
    end
  end

  def onTouchEnded(touch)
    @touchBeginPoint = nil

    point = @bg.convertTouchToNodeSpace(touch)
    puts("onTouchEnded: #{point.x},#{point.y}")

    block = findTouchedBlock(touch)
    puts("touch=#{block}")
    if block
      blocks = findSameColorNeighboringBlocks(block)
      blocks.each do |b|
        puts("remove=#{b}")
        b.removeFromParentAndCleanup(true)
      end
      if 0<blocks.size
        SimpleAudioEngine.sharedEngine.playEffect(MP3_REMOVE_BLOCK)
      end
    end
  end

  def onTouchCanceled(touch)
    onTouchEnded(touch)
  end

  def findTouchedBlock(touch)
    point = @bg.convertTouchToNodeSpace(touch)

    (0...BLOCK_MAX_X).each do |_x|
      (0...BLOCK_MAX_Y).each do |_y|
        tag = blockTag(_x,_y)
        block = @bg.getChildByTag(tag)
        if block && block.boundingBox.containsPoint(ccp(point.x,point.y))
          #p "findTouchedBlock x=#{_x} x=#{_y} tag=#{tag}"
          return block
        end
      end
    end

    return nil
  end

  def findSameColorNeighboringBlocks(block, blocks=[])
    [-1, +1, -100, +100].each do |n|
      b = @bg.getChildByTag(block.getTag()+n)
      if b && b.color==block.color && !blocks.include?(b)
        blocks << b
        findSameColorNeighboringBlocks(b, blocks)
      end
    end
    return blocks
  end
end

begin
  d = Cocos2d::CCDirector.sharedDirector
  d.setContentScaleFactor(768.0 / d.getWinSize.height)

  nyangame = NyanGame.new
  d.runWithScene(nyangame.scene.cc_object)
rescue => e
  puts "ERROR #{e.inspect} #{e.backtrace.first}"
end
