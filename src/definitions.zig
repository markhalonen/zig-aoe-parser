pub const Position = struct { x: f32, y: f32 };

pub const Object = struct {
    name: []const u8,
    class_id: u32,
    object_id: u32,
    instance_id: u32,
    index: u32,
    position: Position,
};
