class Block < Sprite
  attr_reader :color
  attr_accessor :next_x, :next_y
  def initialize(color)
    @cc_class_name = 'CCSprite'
    super(color.to_s + ".png")

    @color = color
    @next_x = -1
    @next_y = -1
  end
  def to_s
    super + " #{color} #{getTag} #{next_x} #{next_y}"
  end
end

class NyanGame
  attr_reader :zorder, :tag
  COLORS = [:red, :blue, :yellow, :green, :gray]
  BLOCK_MAX_X = 8
  BLOCK_MAX_Y = 8
  MP3_REMOVE_BLOCK = "removeBlock.mp3"
  REMOVEING_TIME = 0.1
  MOVING_TIME_1  = 0.2

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

  def blockTagToXY(blockTag)
    t = blockTag - tag[:block_base]
    return [(t/100).floor, t%100]
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
      if 0<blocks.size
        @animating = true
        delete_blocks(blocks)
        move_blocks1(blocks)
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

  def delete_blocks(blocks)
    blocks.each_with_index do |b, index|
      scale_action = Cocos2d::CCScaleTo.create(REMOVEING_TIME, 0)
      remove_action = Cocos2d::CCCallFunc.create do
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

  def move_blocks1(blocks)
    blocks.each_with_index do |b, index|
      x,y = blockTagToXY(b.getTag())
      ((y+1)..(BLOCK_MAX_Y-1)).each do |y0|
        b0 = @bg.getChildByTag(blockTag(x,y0))
        if b0
          if b0.next_y == -1
            b0.next_y = y0
            b0.next_x = x
          end
          b0.next_y -= 1
        end
      end
    end
    run_move_actions

    schedule_once(MOVING_TIME_1) do |a,b|
      move_blocks2
    end
  end

  def move_blocks2
    puts "move_blocks2"
  end

  def run_move_actions
    (0...BLOCK_MAX_X).each do |_x|
      (0...BLOCK_MAX_Y).each do |_y|
        b = @bg.getChildByTag(blockTag(_x,_y))
        if b && 0<=b.next_x && 0<=b.next_y
          move_action = Cocos2d::CCMoveTo.create(MOVING_TIME_1, blockCCPoint(b.next_x, b.next_y))
          b.runAction(move_action)
          b.setTag(blockTag(b.next_x, b.next_y))
          b.next_x = -1
          b.next_y = -1
        end
      end
    end
  end

  def schedule_once(delay, *args, &block)
    scheduler = Cocos2d::CCDirector.sharedDirector.getScheduler

    entry_id = scheduler.scheduleScriptFunc(delay, false) do
      scheduler.unscheduleScriptEntry(entry_id)
      block.call(*args)
    end

    nil # dummy statement for https://github.com/mruby/mruby/issues/1992
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
