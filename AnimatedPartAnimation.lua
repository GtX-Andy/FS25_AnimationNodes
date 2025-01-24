--[[
Copyright (C) GtX (Andy), 2022

Author: GtX | Andy
Date: 14.02.2022
Revision: FS25-01

Contact:
https://forum.giants-software.com
https://github.com/GtX-Andy/FS25_AnimationNodes

Important:
Free for use in mods (FS25 Only) - no permission needed.
No modifications may be made to this script, including conversion to other game versions without written permission from GtX | Andy
Copying or removing any part of this code for external use without written permission from GtX | Andy is prohibited.

Frei verwendbar (Nur LS25) - keine erlaubnis nötig
Ohne schriftliche Genehmigung von GtX | Andy dürfen keine Änderungen an diesem Skript vorgenommen werden, einschließlich der Konvertierung in andere Spielversionen
Das Kopieren oder Entfernen irgendeines Teils dieses Codes zur externen Verwendung ohne schriftliche Genehmigung von GtX | Andy ist verboten.
]]

AnimatedPartAnimation = {}

local modName = g_currentModName or ""
local modDirectory = g_currentModDirectory or ""

local customClassName = modName .. ".AnimatedPartAnimation"
local AnimatedPartAnimation_mt = Class(AnimatedPartAnimation, Animation)

function AnimatedPartAnimation.new(customMt)
    local self = Animation.new(customMt or AnimatedPartAnimation_mt)

    self.currentTime = 0

    self.partActive = false
    self.partEnabled = false

    self.speedScale = 1
    self.looping = false

    self.animationTime = 0
    self.animationMaxTime = 0
    self.direction = 0
    self.duration = 0

    self.animationParts = {}
    self.sharedLoadRequestIds = {}

    return self
end

function AnimatedPartAnimation:load(xmlFile, key, components, owner, i3dMappings)
    if not xmlFile:hasProperty(key) then
        return nil
    end

    self.owner = owner

    self.sequenceOnTime = xmlFile:getValue(key .. "#sequenceOnTime", 0) * 1000
    self.sequenceOffTime = xmlFile:getValue(key .. "#sequenceOffTime", 0) * 1000

    self.useRunTimes = self.sequenceOnTime > 0 and self.sequenceOffTime > 0

    if xmlFile:hasProperty(key .. ".clip") then
        local skeleton = xmlFile:getValue(key .. ".clip#node", nil, components, i3dMappings)
        local clipName = xmlFile:getValue(key .. ".clip#name")

        if skeleton ~= nil and clipName ~= nil then
            local characterFilename = xmlFile:getValue(key .. ".clip#characterFilename")
            local animationFilename = xmlFile:getValue(key .. ".clip#animationFilename")

            self.skeleton = skeleton
            self.clipName = clipName

            self.clipTrack = xmlFile:getValue(key .. ".clip#track", 0)
            self.looping = xmlFile:getValue(key .. ".clip#looping", false)
            self.speedScale = xmlFile:getValue(key .. ".clip#speedScale", self.speedScale)

            if characterFilename ~= nil then
                characterFilename = Utils.getFilename(characterFilename, modDirectory)

                local args = {
                    skeletonNode = xmlFile:getValue(key .. ".clip#skeletonNode", "0"),
                    xmlFile = xmlFile,
                    key = key
                }

                if animationFilename ~= nil then
                    self.animationFilename = Utils.getFilename(animationFilename, modDirectory)
                end

                local sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(characterFilename, false, false, self.onSharedMeshFileLoaded, self, args)

                if self.sharedLoadRequestIds == nil then
                    self.sharedLoadRequestIds = {}
                end

                table.insert(self.sharedLoadRequestIds, sharedLoadRequestId)
            else
                if animationFilename ~= nil then
                    self.animationFilename = Utils.getFilename(animationFilename, modDirectory)

                    local sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(self.animationFilename, false, false, self.onSharedAnimationFileLoaded, self, {xmlFile = xmlFile, key = key})

                    if self.sharedLoadRequestIds == nil then
                        self.sharedLoadRequestIds = {}
                    end

                    table.insert(self.sharedLoadRequestIds, sharedLoadRequestId)
                else
                    self:applyAnimation(xmlFile, key)
                end
            end
        end
    elseif xmlFile:hasProperty(key .. ".animation") then
        self.duration = xmlFile:getValue(key .. ".animation#duration", self.duration)

        xmlFile:iterate(key .. ".animation.part", function (_, partKey)
            local node = xmlFile:getValue(partKey .. "#node", nil, components, i3dMappings)

            if node ~= nil then
                local part = {
                    node = node,
                    frames = {}
                }

                local hasFrames = false

                xmlFile:iterate(partKey .. ".keyFrame", function (_, frameKey)
                    local keyframe = {
                        time = xmlFile:getValue(frameKey .. "#time"),
                        self:loadFrameValues(xmlFile, frameKey, node)
                    }

                    self.animationMaxTime = math.max(keyframe.time, self.animationMaxTime)

                    table.insert(part.frames, keyframe)

                    hasFrames = true
                end)

                if hasFrames then
                    table.insert(self.animationParts, part)
                end
            end
        end)

        if #self.animationParts > 0 then
            for _, part in ipairs(self.animationParts) do
                part.animCurve = AnimCurve.new(linearInterpolatorN)

                for _, frame in ipairs(part.frames) do
                    if self.duration == nil then
                        frame.time = frame.time / self.animationMaxTime
                    end

                    part.animCurve:addKeyframe(frame)
                end
            end

            if self.duration == nil then
                self.duration = self.animationMaxTime
            end

            self.duration = self.duration * 1000
            self:setAnimTime(0)

            if g_client ~= nil then
                self.sampleMoving = g_soundManager:loadSampleFromXML(xmlFile, key .. ".sounds", "moving", modDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil)
                self.samplePosEnd = g_soundManager:loadSampleFromXML(xmlFile, key .. ".sounds", "posEnd", modDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil)
                self.sampleNegEnd = g_soundManager:loadSampleFromXML(xmlFile, key .. ".sounds", "negEnd", modDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil)
            end
        end
    else
        Logging.xmlWarning(xmlFile, "No animation or animation clip for '%s'!", key)

        return nil
    end

    return self
end

function AnimatedPartAnimation:loadFrameValues(xmlFile, key, node)
    local rx, ry, rz = xmlFile:getValue(key .. "#rotation", {
        getRotation(node)
    })

    local x, y, z = xmlFile:getValue(key .. "#translation", {
        getTranslation(node)
    })

    local sx, sy, sz = xmlFile:getValue(key .. "#scale", {
        getScale(node)
    })

    local isVisible = xmlFile:getValue(key .. "#visibility", true)
    local visibility = 1

    if not isVisible then
        visibility = 0
    end

    return x, y, z, rx, ry, rz, sx, sy, sz, visibility
end

function AnimatedPartAnimation:delete()
    self.isDeleted = true

    if self.sampleMoving ~= nil then
        g_soundManager:deleteSample(self.sampleMoving)

        self.sampleMoving = nil
    end

    if self.samplePosEnd ~= nil then
        g_soundManager:deleteSample(self.samplePosEnd)

        self.samplePosEnd = nil
    end

    if self.sampleNegEnd ~= nil then
        g_soundManager:deleteSample(self.sampleNegEnd)

        self.sampleNegEnd = nil
    end

    g_effectManager:deleteEffects(self.effects)
    self.effects = nil

    if self.sharedLoadRequestIds ~= nil then
        for _, sharedLoadRequestId in pairs (self.sharedLoadRequestIds) do
            g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)
        end

        self.sharedLoadRequestIds = nil
    end

    AnimatedPartAnimation:superClass().delete(self)
end

function AnimatedPartAnimation:update(dt)
    AnimatedPartAnimation:superClass().update(self, dt)

    if self.partEnabled and self.useRunTimes then
        self.currentTime = self.currentTime - dt

        if self.currentTime <= 0 then
            if self.partActive then
                self.currentTime = self.sequenceOffTime
                self:setAnimationState(false)
            else
                self.currentTime = self.sequenceOnTime
                self:setAnimationState(true)
            end
        end
    end

    if self.direction ~= 0 and self.duration > 0 then
        local animationTime = math.clamp(self.animationTime + self.direction * dt / self.duration, 0, 1)

        self:setAnimTime(animationTime)

        if animationTime == 0 or animationTime == 1 then
            self.direction = 0

            if self.sampleMoving ~= nil and self.sampleMoving.isPlaying then
                g_soundManager:stopSample(self.sampleMoving)
                self.sampleMoving.isPlaying = false
            end

            if self.samplePosEnd ~= nil and animationTime == 1 then
                g_soundManager:playSample(self.samplePosEnd)
            elseif self.sampleNegEnd ~= nil and animationTime == 0 then
                g_soundManager:playSample(self.sampleNegEnd)
            end
        elseif self.sampleMoving ~= nil then
            if self.direction ~= 0 then
                if not self.sampleMoving.isPlaying then
                    g_soundManager:playSample(self.sampleMoving)
                    self.sampleMoving.isPlaying = true
                end
            elseif self.sampleMoving.isPlaying then
                g_soundManager:stopSample(self.sampleMoving)
                self.sampleMoving.isPlaying = false
            end
        end
    end
end

function AnimatedPartAnimation:isRunning()
    return (self.partEnabled and self.useRunTimes) or self.direction ~= 0
end

function AnimatedPartAnimation:start()
    if not self.partEnabled then
        self.partEnabled = true

        self:setAnimationState(true)

        return true
    end

    return false
end

function AnimatedPartAnimation:stop()
    if self.partEnabled then
        self.partEnabled = false

        self:setAnimationState(false)

        return true
    end

    return false
end

function AnimatedPartAnimation:reset()
    self.partEnabled = false

    if self.sampleMoving ~= nil and self.sampleMoving.isPlaying then
        g_soundManager:stopSample(self.sampleMoving)
        self.sampleMoving.isPlaying = false
    end

    self:setAnimationState(false)

    if self.effects ~= nil then
        g_effectManager:resetEffects(self.effects)
    end

    self.direction = 0
    self:setAnimTime(0)
end

function AnimatedPartAnimation:setAnimationState(partActive)
    self.partActive = partActive

    if partActive then
        self.currentTime = self.sequenceOnTime

        if self.duration > 0 then
            self.direction = 1
        end

        if self.clipCharacterSet ~= nil then
            enableAnimTrack(self.clipCharacterSet, self.clipTrack)

            setAnimTrackSpeedScale(self.clipCharacterSet, self.clipTrack, self.speedScale)

            if not self.looping then
                setAnimTrackTime(self.clipCharacterSet, self.clipTrack, math.max(getAnimTrackTime(self.clipCharacterSet, self.clipTrack), 0))
            end

            if self.effects ~= nil then
                if self.effectsFillTypeIndex ~= nil then
                    g_effectManager:setEffectTypeInfo(self.effects, self.effectsFillTypeIndex)
                end

                g_effectManager:startEffects(self.effects)
            end
        end
    else
        self.currentTime = self.sequenceOffTime

        if self.duration > 0 then
            self.direction = -1
        end

        if self.clipCharacterSet ~= nil then
            if self.effects ~= nil then
                g_effectManager:stopEffects(self.effects)
            end

            if self.looping then
                setAnimTrackTime(self.clipCharacterSet, self.clipTrack, 0, true)
                disableAnimTrack(self.clipCharacterSet, self.clipTrack)
            else
                enableAnimTrack(self.clipCharacterSet, self.clipTrack)
                setAnimTrackTime(self.clipCharacterSet, self.clipTrack, math.min(getAnimTrackTime(self.clipCharacterSet, 0), self.clipDuration))
                setAnimTrackSpeedScale(self.clipCharacterSet, self.clipTrack, -self.speedScale)
            end
        end
    end
end

function AnimatedPartAnimation:onSharedMeshFileLoaded(rootNode, failedReason, args)
    if rootNode ~= 0 and rootNode ~= nil then
        if not self.isDeleted then
            local linkNode = self.skeleton

            link(linkNode, rootNode)
            self.skeleton = I3DUtil.indexToObject(rootNode, args.skeletonNode or "0")

            if self.animationFilename ~= nil then
                local sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(self.animationFilename, false, false, self.onSharedAnimationFileLoaded, self, {xmlFile = args.xmlFile, key = args.key})

                if self.sharedLoadRequestIds == nil then
                    self.sharedLoadRequestIds = {}
                end

                table.insert(self.sharedLoadRequestIds, sharedLoadRequestId)
            else
                self:applyAnimation(args.xmlFile, args.key)
            end
        end
    end
end

function AnimatedPartAnimation:onSharedAnimationFileLoaded(i3dNode, failedReason, args)
    if i3dNode ~= 0 and i3dNode ~= nil then
        if not self.isDeleted then
            cloneAnimCharacterSet(getChildAt(i3dNode, 0), getParent(self.skeleton))
            self:applyAnimation(args.xmlFile, args.key)
        end

        delete(i3dNode)
    end
end

function AnimatedPartAnimation:applyAnimation(xmlFile, key)
    local characterSet = getAnimCharacterSet(self.skeleton)
    local clipIndex = getAnimClipIndex(characterSet, self.clipName)

    xmlFile = xmlFile or self.owner.xmlFile

    if clipIndex == -1 then
        Logging.error("Animation clip with name '%s' does not exist in '%s'", self.clipName, self.animationFilename or (xmlFile ~= nil and xmlFile.filename) or "XML file")

        return
    end

    if xmlFile ~= nil and key ~= nil and xmlFile:hasProperty(key .. ".clip.effects") then
        -- No i3dMappings as this is directly loaded as a child of the skeleton
        local effects = g_effectManager:loadEffect(xmlFile, key .. ".clip.effects", self.skeleton, self.owner, nil)

        if effects and #effects > 0 then
            local fillTypeName = xmlFile:getValue(key .. ".clip.effects#fillType", "NO_FILLTYPE")
            local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)

            if fillTypeIndex ~= nil then
                self.effectsFillTypeIndex = fillTypeIndex
                g_effectManager:setEffectTypeInfo(effects, fillTypeIndex)
            end

            self.effects = effects
        end
    end

    assignAnimTrackClip(characterSet, self.clipTrack, clipIndex)
    setAnimTrackLoopState(characterSet, self.clipTrack, self.looping)

    self.clipDuration = getAnimClipDuration(characterSet, clipIndex)
    self.clipCharacterSet = characterSet
    self.clipIndex = clipIndex

    enableAnimTrack(characterSet, self.clipTrack)
    self:setAnimationState(self.partActive)
end

function AnimatedPartAnimation:setAnimTime(animationTime)
    for _, part in pairs(self.animationParts) do
        local x, y, z, rx, ry, rz, sx, sy, sz, vis = part.animCurve:get(animationTime)

        setTranslation(part.node, x, y, z)
        setRotation(part.node, rx, ry, rz)
        setScale(part.node, sx, sy, sz)
        setVisibility(part.node, vis == 1)
    end

    self.animationTime = animationTime
end

function AnimatedPartAnimation.registerAnimationClassXMLPaths(schema, basePath)
    schema:register(XMLValueType.FLOAT, basePath .. ".animationNode(?)#sequenceOnTime", "(AnimatedPartAnimation) When used with 'sequenceOffTime' this is the time the animation is active for in sequence (sec.)", 0)
    schema:register(XMLValueType.FLOAT, basePath .. ".animationNode(?)#sequenceOffTime", "(AnimatedPartAnimation) When used with 'sequenceOnTime' this is the time the animation is inactive for in sequence (sec.)", 0)

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".animationNode(?).clip#node", "(AnimatedPartAnimation) Animation skeleton node or link node when using characterFilename")
    schema:register(XMLValueType.STRING, basePath .. ".animationNode(?).clip#name", "(AnimatedPartAnimation) Animation clipName")

    schema:register(XMLValueType.STRING, basePath .. ".animationNode(?).clip#characterFilename", "(AnimatedPartAnimation) External mesh or combined file")
    schema:register(XMLValueType.STRING, basePath .. ".animationNode(?).clip#skeletonNode", "(AnimatedPartAnimation) Skeleton node index to attach animation to. Uses 'characterFilename' i3d if 'animationFilename' i3d is not provided.", "0")
    schema:register(XMLValueType.STRING, basePath .. ".animationNode(?).clip#animationFilename", "(AnimatedPartAnimation) External animation file to link with mesh")

    schema:register(XMLValueType.INT, basePath .. ".animationNode(?).clip#track", "(AnimatedPartAnimation) Track index", 0)
    schema:register(XMLValueType.BOOL, basePath .. ".animationNode(?).clip#looping", "(AnimatedPartAnimation) Use looping", false)
    schema:register(XMLValueType.INT, basePath .. ".animationNode(?).clip#speedScale", "(AnimatedPartAnimation) Speed scale to use", 1)

    EffectManager.registerEffectXMLPaths(schema, basePath .. ".animationNode(?).clip.effects")
    schema:register(XMLValueType.STRING, basePath .. ".animationNode(?).clip.effects#fillType", "Fill type that is applied to effect")

    schema:register(XMLValueType.FLOAT, basePath .. ".animationNode(?).animation#duration", "(AnimatedPartAnimation) Animation duration (sec.)", 0)
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".animationNode(?).animation.part(?)#node", "(AnimatedPartAnimation) Part node")
    schema:register(XMLValueType.FLOAT, basePath .. ".animationNode(?).animation.part(?).keyFrame(?)#time", "(AnimatedPartAnimation) Key time")
    schema:register(XMLValueType.VECTOR_ROT, basePath .. ".animationNode(?).animation.part(?).keyFrame(?)#rotation", "(AnimatedPartAnimation) Key rotation", "values read from i3d node")
    schema:register(XMLValueType.VECTOR_TRANS, basePath .. ".animationNode(?).animation.part(?).keyFrame(?)#translation", "(AnimatedPartAnimation) Key translation", "values read from i3d node")
    schema:register(XMLValueType.VECTOR_SCALE, basePath .. ".animationNode(?).animation.part(?).keyFrame(?)#scale", "(AnimatedPartAnimation) Key scale", "values read from i3d node")
    schema:register(XMLValueType.BOOL, basePath .. ".animationNode(?).animation.part(?).keyFrame(?)#visibility", "(AnimatedPartAnimation) Key visibility", true)

    SoundManager.registerSampleXMLPaths(schema, basePath .. ".animationNode(?).sounds", "moving")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".animationNode(?).sounds", "posEnd")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".animationNode(?).sounds", "negEnd")
end

-- There is no way to add custom animation nodes to registration without manually doing this, here is a work around.
-- Other modders are free to use the below code as part of their own Animation scripts but please do not modify as it must support all mod scripts and no need for multiple appended functions
if AnimationManager.CUSTOM_CLASSES_TO_REGISTER_XML_PATH == nil then
    AnimationManager.CUSTOM_CLASSES_TO_REGISTER_XML_PATH = {}

    AnimationManager.registerAnimationNodesXMLPaths = Utils.appendedFunction(AnimationManager.registerAnimationNodesXMLPaths, function(schema, basePath)
        local classes = AnimationManager.CUSTOM_CLASSES_TO_REGISTER_XML_PATH

        if classes == nil and g_animationManager.registeredAnimationClasses ~= nil then
            classes = g_animationManager.registeredAnimationClasses
        end

        if classes ~= nil then
            schema:setXMLSharedRegistration("AnimationNode", basePath)

            for className, animationClass in pairs (classes) do
                if string.find(tostring(className), ".") and rawget(animationClass, "registerAnimationClassXMLPaths") then
                    animationClass.registerAnimationClassXMLPaths(schema, basePath)
                end
            end

            schema:setXMLSharedRegistration()
        end
    end)
end

-- Add class to the table so it will be available
AnimationManager.CUSTOM_CLASSES_TO_REGISTER_XML_PATH[customClassName] = AnimatedPartAnimation

-- Add class directly so that the class name includes the mod environment for no conflicts
-- @Giants do not localise this correctly for animations using 'g_animationManager:registerAnimationClass', it is only done for Effects as of v1.4.1.0
if g_animationManager.registeredAnimationClasses ~= nil then
    g_animationManager.registeredAnimationClasses[customClassName] = AnimatedPartAnimation
else
    Logging.error("Failed to register animation class '%s' due to base game code changes. Please report: https://github.com/GtX-Andy/FS25_AnimationNodes", customClassName)
end
