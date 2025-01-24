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

BeaconLightAnimation = {}

local modName = g_currentModName or ""
local modDirectory = g_currentModDirectory or ""

local customClassName = modName .. ".BeaconLightAnimation"
local BeaconLightAnimation_mt = Class(BeaconLightAnimation, Animation)

function BeaconLightAnimation.new(customMt)
    local self = Animation.new(customMt or BeaconLightAnimation_mt)

    self.customEnvironment = modName
    self.baseDirectory = modDirectory

    self.beaconLight = nil
    self.beaconActive = false

    self.isDeleted = false

    return self
end

function BeaconLightAnimation:load(xmlFile, key, components, owner, i3dMappings)
    if not xmlFile:hasProperty(key) then
        return nil
    end

    self.owner = owner
    self.xmlFile = xmlFile

    if owner ~= nil then
        self.customEnvironment = owner.customEnvironment or modName
        self.baseDirectory = owner.baseDirectory or modDirectory
    end

    local linkNode = xmlFile:getValue(key .. "#node", nil, components, i3dMappings) -- Also acts as the 'rotatorNode' when light is not loaded via xml
    local xmlFilename = xmlFile:getValue(key .. "#filename", nil, self.baseDirectory)

    if xmlFilename == nil then
        local hasDynamicStaticLights = false
        local staticLights = {}

        for _, staticLightKey in xmlFile:iterator(key .. ".staticLight") do
            local node = xmlFile:getValue(staticLightKey .. "#node", nil, components, i3dMappings)

            if node ~= nil then
                local intensityScaleMinDistance = xmlFile:getValue(staticLightKey .. ".intensityScale#minDistance")
                local intensityScaleMinIntensity = xmlFile:getValue(staticLightKey .. ".intensityScale#minIntensity")
                local intensityScaleMaxDistance = xmlFile:getValue(staticLightKey .. ".intensityScale#maxDistance")
                local intensityScaleMaxIntensity = xmlFile:getValue(staticLightKey .. ".intensityScale#maxIntensity")

                local staticLight = {
                    node = node,
                    intensityScaleMinDistance = intensityScaleMinDistance,
                    intensityScaleMinIntensity = intensityScaleMinIntensity,
                    intensityScaleMaxDistance = intensityScaleMaxDistance,
                    intensityScaleMaxIntensity = intensityScaleMaxIntensity
                }

                staticLight.intensity = xmlFile:getValue(staticLightKey .. "#intensity", 1)
                staticLight.multiBlink = xmlFile:getValue(staticLightKey .. "#multiBlink", false)
                staticLight.multiBlinkParameters = xmlFile:getValue(staticLightKey .. "#multiBlinkParameters", "2 5 50 0", true)
                staticLight.uvOffsetParameter = xmlFile:getValue(staticLightKey .. "#uvOffsetParameter", 0)
                staticLight.minDistance = xmlFile:getValue(staticLightKey .. "#minDistance", 0)

                staticLight.hasDynamicIntensity = intensityScaleMinDistance ~= nil and intensityScaleMinIntensity ~= nil and intensityScaleMaxDistance ~= nil and intensityScaleMaxIntensity ~= nil
                hasDynamicStaticLights = hasDynamicStaticLights or staticLight.hasDynamicIntensity or staticLight.minDistance > 0

                table.insert(staticLights, staticLight)
            end
        end

        if staticLights ~= nil and #staticLights > 0 then
            local speed = xmlFile:getValue(key.."#speed")
            local intensity = xmlFile:getValue(key.."#intensity", 1)

            local realLight = xmlFile:getValue(key.."#realLight", nil, components, i3dMappings)
            local realLightRangeScale = xmlFile:getValue(key.."#realLightRange", 1)

            local beaconLight = BeaconLight.new(self)

            beaconLight:setXMLSettings(speed, intensity, nil, nil)
            beaconLight:setRealLight(true, realLight, realLightRangeScale)

            beaconLight.rotatorNode = linkNode

            beaconLight.staticLights = staticLights
            beaconLight.hasStaticLights = true
            beaconLight.hasDynamicStaticLights = hasDynamicStaticLights

            beaconLight:onFinished(true)

            self.beaconLight = beaconLight
        end

        self.xmlFile = nil
    else
        if linkNode ~= nil then
            local isReference, _, runtimeLoaded = getReferenceInfo(linkNode)
            if isReference and runtimeLoaded then
                Logging.xmlWarning(xmlFile, "Beacon light link node '%s' is a runtime loaded reference, please load beacon lights only via XML!", getName(linkNode))
                return
            end

            local speed = xmlFile:getValue(key .. "#speed")

            local realLight = xmlFile:getValue(key .. "#realLight", nil, components, i3dMappings)
            local useRealLights = xmlFile:getValue(key .. "#useRealLights", realLight == nil)

            local realLightRangeScale = xmlFile:getValue(key .. "#realLightRange", 1)
            local intensity = xmlFile:getValue(key .. "#intensity", 1)

            local mountType = xmlFile:getValue(key .. "#mountType")
            local variationName = xmlFile:getValue(key .. "#variationName")

            local beaconLight = BeaconLight.new(self)

            beaconLight:setXMLSettings(speed, intensity, mountType, variationName)
            beaconLight:setRealLight(useRealLights, realLight, realLightRangeScale)

            beaconLight:setCallback(function(success)
                if success then
                    self.beaconLight = beaconLight

                    if self.beaconActive then
                        beaconLight:setIsActive(true)
                    end

                    self.xmlFile = nil
                end
            end)

            beaconLight:loadFromXML(linkNode, xmlFilename, self.baseDirectory)
        else
            Logging.xmlWarning(xmlFile, "Missing link node for beacon light in '%s'", key)
        end
    end

    return self
end

function BeaconLightAnimation:delete()
    if self.beaconLight ~= nil then
        self.beaconLight:delete()
        self.beaconLight = nil
    end

    self.isDeleted = true

    BeaconLightAnimation:superClass().delete(self)
end

function BeaconLightAnimation:isRunning()
    return self.beaconActive
end

function BeaconLightAnimation:start()
    if not self.beaconActive then
        self.beaconActive = true

        if self.beaconLight ~= nil then
            self.beaconLight:setIsActive(true)
        end

        return true
    end

    return false
end

function BeaconLightAnimation:stop()
    if self.beaconActive then
        self.beaconActive = false

        if self.beaconLight ~= nil then
            self.beaconLight:setIsActive(false)
        end

        return true
    end

    return false
end

function BeaconLightAnimation:reset()
    self.beaconActive = false

    if self.beaconLight ~= nil then
        self.beaconLight:setIsActive(false)
    end

    return true
end

function BeaconLightAnimation:loadSubSharedI3DFile(filename, callOnCreate, addToPhysics, asyncCallbackFunction, asyncCallbackObject, asyncCallbackArguments)
    return g_i3DManager:loadSharedI3DFileAsync(filename, callOnCreate, addToPhysics, asyncCallbackFunction, asyncCallbackObject, asyncCallbackArguments)
end

function BeaconLightAnimation.registerAnimationClassXMLPaths(schema, basePath)
    BeaconLight.registerVehicleXMLPaths(schema, basePath .. ".animationNode(?)")
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
AnimationManager.CUSTOM_CLASSES_TO_REGISTER_XML_PATH[customClassName] = BeaconLightAnimation

-- Add class directly so that the class name includes the mod environment for no conflicts
-- @Giants do not localise this correctly for animations using 'g_animationManager:registerAnimationClass', it is only done for Effects as of v1.4.1.0
if g_animationManager.registeredAnimationClasses ~= nil then
    g_animationManager.registeredAnimationClasses[customClassName] = BeaconLightAnimation
else
    Logging.error("Failed to register animation class '%s' due to base game code changes. Please report: https://github.com/GtX-Andy/FS25_AnimationNodes", customClassName)
end
