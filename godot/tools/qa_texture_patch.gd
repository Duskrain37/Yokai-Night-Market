extends SceneTree
func _init():
 for i in range(1,4):
  var p="res://assets/sprites/mushroom-growth-%d.png" % i
  var t=load(p)
  print(p," object=",t," size=",t.get_size()," sample=",t.get_image().get_pixel(300,500))
 quit()
