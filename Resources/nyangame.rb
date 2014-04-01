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
    @win_size = Cocos2d::CCDirector.sharedDirector.getWinSize
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
        when Cocos2d::CCTOUCHBEGAN
          onTouchBegan(touch)
        when Cocos2d::CCTOUCHMOVED
          onTouchMoved(touch)
        when Cocos2d::CCTOUCHENDED
          onTouchEnded(touch)
        when Cocos2d::CCTOUCHCANCELLED
          onTouchCanceled(touch)
        else
          raise "unknown eventType=#{eventType}"
        end
      end
      @layer.setTouchMode(Cocos2d::KCCTouchesOneByOne)
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

      CocosDenshion::SimpleAudioEngine.sharedEngine.preloadEffect(MP3_REMOVE_BLOCK)
    end
    @scene
  end

  def blockCCPoint(x, y)
    offsetX = @bg.getContentSize.width  * 0.168
    offsetY = @bg.getContentSize.height * 0.029
    return Cocos2d::ccp(
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
    glPt = Cocos2d::CCDirector.sharedDirector.convertToGL(touch.getLocationInView)

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
      blocks.each_with_index do |b, index|
        scale_action = Cocos2d::CCScaleTo.create(1.0, 0)
        remove_action = Cocos2d::CCCallFunc.create do
          puts("remove=#{b}")
          b.removeFromParentAndCleanup(true)
        end
        action = Cocos2d::CCSequence.createWithTwoActions(scale_action, remove_action)
        if index == 0
          sound_action = Cocos2d::CCCallFunc.create do
            CocosDenshion::SimpleAudioEngine.sharedEngine.playEffect(MP3_REMOVE_BLOCK)
          end
          action = Cocos2d::CCSpawn.createWithTwoActions(action, sound_action)
        end
        b.runAction(action)
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
        if block && block.boundingBox.containsPoint(Cocos2d::ccp(point.x,point.y))
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
