include Cocos2d
include CocosDenshion

class Block
  def initialize(color)
    @color = color
    @next_pos = nil
  end
  def sprite
    @sprite ||= CCSprite.create(@color.to_s + ".png")
  end
  attr_accessor :next_pos
end

class NyanGame
  attr_reader :zorder, :tag
  COLORS = [:red, :blue, :yellow, :green, :gray]
  BLOCK_MAX_X = 8
  BLOCK_MAX_Y = 8

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

    @blocks_by_color = {}
    COLORS.each{|c| @blocks_by_color[c] = [] }

    @animating = false
    @score     = 0
  end

  def scene
    unless @scene
      @layer = CCLayer.create

      @touchBeginPoint = nil
      @layer.registerScriptTouchHandler do |eventType, x, y|
        case eventType
        when CCTOUCHBEGAN
          onTouchBegan(x, y)
        when CCTOUCHMOVED
          onTouchMoved(x, y)
        when CCTOUCHENDED
          onTouchEnded(x, y)
        when CCTOUCHCANCELLED
          onTouchCanceled(x, y)
        else
          raise "unknown eventType=#{eventType}"
        end
      end
      @layer.setTouchMode(KCCTouchesOneByOne)
      @layer.setTouchEnabled(true)

      @bg = CCSprite.create("background.png")
      @bg.setPosition(@win_size.width/2, @win_size.height/2)
      @layer.addChild(@bg, zorder[:bg], tag[:bg])

      @scene = CCScene.create
      @scene.addChild(@layer)

      @block = Block.new(:red)
      @block_size = @block.sprite.getContentSize.height

      if "demo"
        sp = @block.sprite
        sp.setPosition(@win_size.width/2, @win_size.height/2)
        @bg.addChild(sp, zorder[:block], tag[:block])
      end

      _createBlocks
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
        sp = block.sprite
        sp.setPosition(blockCCPoint(x,y))
        @blocks_by_color[color] << block
        @bg.addChild(sp, zorder[:block], blockTag(x,y))
      end
    end
  end

  def onTouchBegan(x, y)
    puts("onTouchBegan: #{x},#{y}")
    @touchBeginPoint = {:x=>x, :y=>y}

    return !@animating
  end

  def onTouchMoved(x, y)
    puts("onTouchMoved: #{x},#{y}")
    if @touchBeginPoint
      sp = @block.sprite
      pos = sp.getPosition
      sp.setPosition(
        pos.x + (x - @touchBeginPoint[:x]),
        pos.y + (y - @touchBeginPoint[:y])
      )
      @touchBeginPoint = {:x=>x, :y=>y}
    end
  end

  def onTouchEnded(x, y)
    puts("onTouchEnded: #{x},#{y}")
    @touchBeginPoint = nil

    (0...BLOCK_MAX_X).each do |_x|
      (0...BLOCK_MAX_Y).each do |_y|
        sp = @bg.getChildByTag(blockTag(_x,_y))
        if sp && sp.boundingBox.containsPoint(ccp(x,y))
          p "x=#{_x} x=#{_y}"
        end
      end
    end
  end

  def onTouchCanceled(x, y)
    onTouchEnded(x, y)
  end
end

if true
  d = Cocos2d::CCDirector.sharedDirector
  d.setContentScaleFactor(768.0 / d.getWinSize.height)

  nyangame = NyanGame.new
  d.runWithScene(nyangame.scene)
end
