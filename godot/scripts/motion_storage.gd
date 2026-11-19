## On Windows, the packer can store verified WebP inputs instead of the larger
## re-encoded imports. Ordinary source runs and other platforms keep the imports.
extends RefCounted

class CompactLoader extends ResourceFormatLoader:
	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["nma"])

	func _handles_type(type: StringName) -> bool:
		return type in [&"", &"Texture2D", &"ImageTexture", &"Resource"]

	func _get_resource_type(path: String) -> String:
		return "ImageTexture" if path.ends_with(".nma") else ""

	func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
		var image := decode(FileAccess.get_file_as_bytes(path))
		return ImageTexture.create_from_image(image) if image != null else ERR_FILE_CORRUPT

	static func decode(data: PackedByteArray) -> Image:
		var image := Image.new()
		if image.load_webp_from_buffer(data) != OK:return null
		# Same pre-processing as the desktop texture importer; preserve sampled borders.
		image.fix_alpha_edges()
		return image

static var _loader: CompactLoader

static func path_for(path: String) -> String:
	if not path.begins_with("res://assets/sprites/motion/") or not FileAccess.file_exists(path+".nma"):
		return path
	if _loader == null:
		_loader=CompactLoader.new()
		ResourceLoader.add_resource_format_loader(_loader)
	return path+".nma"
