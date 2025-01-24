# Animation Nodes for Farming Simulator 25

`Farming Simulator  25`&nbsp;&nbsp;&nbsp;&nbsp;`Game Version:  1.4.0.0`

`BeaconLightAnimation - Revision: FS25-01`  
`AnimatedPartAnimation - Revision: FS25-01`

## About
Farming Simulator 25 animation node scripts for use with placeable or vehicle specialisations.

#### &nbsp;&nbsp;&nbsp;&nbsp; - Looking for the [Farming Simulator 22](https://github.com/GtX-Andy/animationNodeAnimations) release?

## Usage
These scripts are free for use in any Farming Simulator 25 **Map** , **Placeable** or **Vehicle** mods for both ***Private*** and ***Public*** release.  

Copying or removing any part of the code contained within these scripts for external use without written permission from GtX | Andy is prohibited.

## Publishing
The publishing of these scripts when they are not included as part of a **Map** , **Placeable** or **Vehicle** mod is not permitted.

Adding these scripts as part of a Global script or standalone script mod is not required or permitted.

All links must return to this [GitHub repository](https://github.com/GtX-Andy/FS25_AnimationNodes).

## Modification / Converting
Only GtX | Andy is permitted to make modifications to this code including but not limited to bug fixes, enhancements or the addition of new features.

Converting these animation or parts there of to other version of the Farming Simulator series is not permitted without written approval from GtX | Andy.

## Versioning
All versioning is controlled by GtX | Andy and not by any other page, individual or company.

## Documentation
The following information is required for these animation scripts to operate. `<animationNodes>` must be supported to use these animations.

Note: Some specializations do not correctly assign the mod custom environment correctly, for example version 1.4.0.0 of the base game **ProductionPoint** does not correctly do this so it must be manually set.

If you receive an invalid class name message when trying to use one of these scripts you will need to add the mod name to the start of the class name in the mod XML.

Example: `FS25_MyGreatMod.BeaconLightAnimation` or `FS25_MyGreatMod.AnimatedPartAnimation`

>### BeaconLightAnimation

It is possible to dynamically load a beacon light with this animation.

```xml
<modDesc descVersion="94">
    <extraSourceFiles>
        <sourceFile filename="BeaconLightAnimation.lua"/>
    </extraSourceFiles>
</modDesc>

<placeable type="myTypeName">
    <animationNodes>
        <animationNode node="node" class="BeaconLightAnimation" filename="$data/shared/assets/beaconLights/lizard/beaconLight05.xml" mountType="SURFACE" variationName="ROTATE" useRealLights="true"/>
    </animationNodes>
</placeable>
```

>### AnimatedPartAnimation

It is possible to play a animation using parts and key frames or animation clips with this animation.
The animations can also include a sequence allowing it to activate and deactivate for defined periods of time.

```xml
<modDesc descVersion="94">
    <extraSourceFiles>
        <sourceFile filename="AnimatedPartAnimation.lua"/>
    </extraSourceFiles>
</modDesc>

<placeable type="myTypeName">
    <animationNodes>
        <!-- USAGE: Mesh and clip part of mod -->
        <animationNode class="AnimatedPartAnimation" >
            <clip node="skeletonNode" name="Animation Name" looping="true"/>
        </animationNode>

        <!-- USAGE: Mesh part of mod with shared animation file -->
        <animationNode class="AnimatedPartAnimation" >
            <clip node="link / mesh node" animationFilename="sharedAnimation.i3d" name="animationName" looping="true"/>
        </animationNode>

        <!-- USAGE: Shared mesh and animation files -->
        <animationNode class="AnimatedPartAnimation" >
            <clip node="linkNode" characterFilename="baker/baker.i3d" animationFilename="baker/animations/bakerAnimations.i3d" skeletonNode="0|0" name="mixingBowl" looping="true"/>
        </animationNode>

        <!-- USAGE: Shared mesh with combined clip file -->
        <animationNode class="AnimatedPartAnimation" >
            <clip node="linkNode" characterFilename="dog/guardDogAnimations.i3d" skeletonNode="0|0" name="sittingSource" looping="true"/>
        </animationNode>

        <!-- USAGE: Similar to animated object but allows on / off sequence times -->
        <animationNode class="AnimatedPartAnimation" sequenceOnTime="10" sequenceOffTime="6">
            <animation duration="3">
                <part node="node">
                    <keyFrame time="0.0" rotation="0 0 0"/>
                    <keyFrame time="1.0" rotation="0 180 0"/>
                </part>
                <part node="node">
                    <keyFrame time="0.0" translation="7.9 1.19 -3.36"/>
                    <keyFrame time="1.0" translation="7.9 3 -3.36"/>
                </part>
            </animation>
        </animationNode>

        <!-- USAGE: Just like animated object, sounds can be used for moving, start and end -->
        <animationNode class="AnimatedPartAnimation">
            <animation duration="0.2">
                <part node="node">
                    <keyFrame time="0.0" rotation="0 0 0"/>
                    <keyFrame time="1.0" rotation="-80 0 0"/>
                </part>
            </animation>

            <sounds>
                <posEnd file="filename.ogg" linkNode="node" volume="0.8" radius="25" innerRadius="3" />
                <negEnd file="filename.ogg" linkNode="node" volume="0.8" radius="25" innerRadius="3" />
            </sounds>
        </animationNode>
    </animationNodes>
</placeable>

```

## Copyright
Copyright (c) 2022 [GtX (Andy)](https://github.com/GtX-Andy)
