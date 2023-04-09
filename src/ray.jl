module Rays

using ...Vectors

const kEPS = 1e-6

struct Ray
  origin::Vec3
  direction::UnitVec3
end

struct HitRecord
  point::Vec3
  normal::UnitVec3
  distance::Float64
end

export Ray, HitRecord, kEPS

end
