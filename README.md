# This is outdated not supported Spine importer. It may be useful only as reference for creating new, true 2d importer, when Godot will supoport 2d meshes. Use https://github.com/jjay/godot-spine-module for godot 2.1 or https://github.com/GodotExplorer/spine for godot 3.0

# Import animations from [Spine](http://esotericsoftware.com)

This is addon for [Godot](http://godotengine.com) engine for importing animations from Spine.
Small video - https://www.youtube.com/watch?v=WB1VCD_Z_0Y

Planned and implemented features:

- [x] Import atlas (with multiply pages, and rotated images)
- [ ] Import separate images
- [x] Import skeleton
- [x] Transform, rotation and scale for rest pose
- [ ] Shear transform for rest pose
- [x] Skeleton animation with weighted meshes (transform, rotate, scale)
- [ ] Skeleton animation for shear transform
- [ ] Skeleton animation optimizations
- [x] Deform animations for meshes attached to a single bone
- [x] Attachments slot animations
- [ ] Color slot animations
- [ ] Sort order animations
- [ ] Inverse kinematics
- [x] inheritRotation:false
- [ ] inheritScale:false
- [x] transform:normal
- [ ] transform:onlyTranslation
- [ ] transform:noRotation
- [ ] transform:noScale
- [ ] transform:noScaleOrReflection


Installation
------------
Copy addons folder to your project, enable Spine Importer in Project Settings/Addons
