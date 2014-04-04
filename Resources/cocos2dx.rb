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
    @@wrap_objects[@cc_object.m_nLuaID] = self
  end

  def self._removeScriptObject(obj)
    @@wrap_objects.delete(obj.m_nLuaID)
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
      if @@wrap_objects[ret.m_nLuaID]
        ret = @@wrap_objects[ret.m_nLuaID]
      end
    end

    return ret
  end
end

Cocos2d::Callback.removeScriptObject = proc do |obj|
 #puts "removeScriptObject m_nLuaID=#{obj.m_nLuaID} dataptr=#{obj.dataptr} retainCount=#{obj.retainCount}"
  Node._removeScriptObject(obj)
end

class Sprite < Node
end

class Layer < Node
end

class Scene < Node
end

class SpriteBatchNode < Node
end

class LabelBMFont < SpriteBatchNode
end
