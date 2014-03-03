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
      sp = @block.sprite
      pos = sp.getPosition
      sp.setPosition(
        pos.x + (point.x - @touchBeginPoint[:x]),
        pos.y + (point.y - @touchBeginPoint[:y])
      )
      @touchBeginPoint = {:x=>point.x, :y=>point.y}
    end
  end

  def onTouchEnded(touch)
    point = @bg.convertTouchToNodeSpace(touch)
    puts("onTouchEnded: #{point.x},#{point.y}")
    @touchBeginPoint = nil

    (0...BLOCK_MAX_X).each do |_x|
      (0...BLOCK_MAX_Y).each do |_y|
        sp = @bg.getChildByTag(blockTag(_x,_y))
        if sp && sp.boundingBox.containsPoint(ccp(point.x,point.y))
          p "x=#{_x} x=#{_y}"
        end
      end
    end
  end

  def onTouchCanceled(touch)
    onTouchEnded(touch)
  end
end

if true
  d = Cocos2d::CCDirector.sharedDirector
  d.setContentScaleFactor(768.0 / d.getWinSize.height)

  nyangame = NyanGame.new
  d.runWithScene(nyangame.scene)
end
