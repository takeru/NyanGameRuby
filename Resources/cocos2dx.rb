class Node
  @@wrap_objects = {}
  @@cc_object_id = 0
  attr_reader :cc_object

  def initialize(*args)
    @cc_class_name ||= 'CC' + self.class.to_s
    unless @cc_constructor_name
      @cc_constructor_name = 'create'
      if 1<=args.size && args[0].kind_of?(Symbol)
        suffix = args.shift
        @cc_constructor_name += suffix.to_s
      end
    end
    @cc_class = Cocos2d.const_get(@cc_class_name)
    args = _wrap_object_to_cc_object(args)
    @cc_object = @cc_class.send(@cc_constructor_name, *args)
    _add_to_wrap_objects
  end

  def _add_to_wrap_objects
    @@cc_object_id += 1
    @cc_object.m_nLuaID = @@cc_object_id
    @@wrap_objects[@cc_object.m_nLuaID] = self
  end

  def self._remove_from_wrap_objects(obj)
    @@wrap_objects.delete(obj.m_nLuaID)
  end

  def _wrap_object_to_cc_object(args)
    args.map do |arg|
      if arg.kind_of?(Node)
        arg.cc_object
      elsif arg.kind_of?(Array)
        _wrap_object_to_cc_object(arg)
      else
        arg
      end
    end
  end

  def method_missing(method, *args, &block)
    args = _wrap_object_to_cc_object(args)

    ret = @cc_object.send(method, *args, &block)

    if ret.kind_of?(Cocos2d::CCNode)
      if @@wrap_objects[ret.m_nLuaID]
        ret = @@wrap_objects[ret.m_nLuaID]
      end
    end

    return ret
  end
end

Cocos2d::Callback.removeScriptObject = proc do |obj|
  Node._remove_from_wrap_objects(obj)
end

class NodeRGBA < Node
end

class Sprite < NodeRGBA
end

class Layer < Node
end

class Scene < Node
end

class SpriteBatchNode < Node
end

class LabelBMFont < SpriteBatchNode
end

class LayerRGBA < Layer
end

class Menu < LayerRGBA
  def self.createWithItem(item)
    new(:WithItem, item)
  end
end

class MenuItem < NodeRGBA
end

class MenuItemSprite < MenuItem
end

class MenuItemImage < MenuItemSprite
end
