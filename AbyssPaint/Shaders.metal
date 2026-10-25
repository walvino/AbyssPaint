#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// MARK: - Uniforms

struct RenderUniforms {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
    float2 canvasSize;
    float zoom;
    float2 pan;
    float rotation;
    float time;
};

struct BrushUniforms {
    BrushParameters params;
    float2 canvasSize;
    float zoom;
    float time;
    uint stampCount;
};

// MARK: - Brush Parameters (matches Swift struct)

struct BrushParameters {
    // Stroke
    float spacing;
    float streamline;
    float jitter;
    float fallOff;
    float taperLength;
    
    // Taper
    float taperOpacity;
    float taperSize;
    float taperPressure;
    float tipShape;
    float touchTaper;
    
    // Shape
    uint shapeSource;
    uint grainSource;
    float shapeRotation;
    float scatter;
    float randomization;
    
    // Grain
    float grainScale;
    float grainZoom;
    float grainRotation;
    float grainDepth;
    uint grainBlendMode;
    float grainBrightness;
    float grainContrast;
    
    // Rendering
    uint renderingMode;
    float flow;
    float wetness;
    float dilution;
    float charge;
    float pull;
    
    // Wet Mix
    float wetMixDilution;
    float wetMixCharge;
    float wetMixPull;
    float wetMixGrade;
    
    // Color Dynamics
    float stampColorJitter;
    float strokeColorJitter;
    float colorPressure;
    float colorTilt;
    float4 secondaryColor;
    float saturation;
    float brightness;
    float purity;
    
    // Dynamics
    float speedSize;
    float speedOpacity;
    float speedJitter;
    float flipX;
    float flipY;
    float rotationDynamics;
    
    // Tablet/Apple Pencil
    float pressureSize;
    float pressureOpacity;
    float pressureFlow;
    float pressureBleed;
    float pressureSmoothing;
    float tiltSize;
    float tiltOpacity;
    float tiltGradient;
    float tiltBleed;
    float azimuthSize;
    float azimuthOpacity;
    
    // Properties
    float maxSize;
    float minSize;
    float maxOpacity;
    float minOpacity;
    float orientToScreen;
    float classicTaper;
};

// MARK: - Stroke Point (matches Swift)

struct StrokePoint {
    float2 position;
    float pressure;
    float2 tilt;
    float azimuth;
    float timestamp;
    float velocity;
};

// MARK: - Stroke Segment

struct StrokeSegment {
    StrokePoint startPoint;
    StrokePoint endPoint;
};

// MARK: - Brush Stamp

struct BrushStamp {
    float2 position;
    float size;
    float rotation;
    float opacity;
    float4 color;
    uint textureIndex;
};

// MARK: - Vertex Structures

struct QuadVertex {
    float2 position;
    float2 texCoord;
};

struct StampInstance {
    float2 position;
    float size;
    float rotation;
    float opacity;
    float4 color;
    uint textureIndex;
};

// MARK: - Blend Mode Enum

enum GPUBlendMode : uint {
    normal = 0,
    multiply = 1,
    screen = 2,
    overlay = 3,
    softLight = 4,
    hardLight = 5,
    colorDodge = 6,
    colorBurn = 7,
    darken = 8,
    lighten = 9,
    difference = 10,
    exclusion = 11,
    hue = 12,
    saturation = 13,
    color = 14,
    luminosity = 15,
    linearBurn = 16,
    linearDodge = 17,
    vividLight = 18,
    linearLight = 19,
    pinLight = 20,
    hardMix = 21,
    subtract = 22,
    divide = 23,
    darkerColor = 24,
    lighterColor = 25
};

// MARK: - Rendering Mode Enum

enum RenderingMode : uint {
    normal = 0,
    glazed = 1,
    wetMix = 2,
    intenseGlazed = 3,
    intenseBlending = 4,
    heavyGlazing = 5
};

// MARK: - Vertex Shaders

vertex float4 vertex_main(QuadVertex in [[stage_in]],
                         constant RenderUniforms& uniforms [[buffer(1)]]) {
    float2 pos = in.position;
    float2 tex = in.texCoord;
    
    // Apply view transform
    float4 viewPos = uniforms.viewMatrix * float4(pos, 0, 1);
    
    // Apply projection
    float4 clipPos = uniforms.projectionMatrix * viewPos;
    
    // Pass texture coordinates
    return clipPos;
}

vertex float4 vertex_brush(QuadVertex in [[stage_in]],
                          uint instanceID [[instance_id]],
                          constant BrushUniforms& uniforms [[buffer(1)]],
                          device StampInstance* instances [[buffer(2)]]) {
    
    StampInstance stamp = instances[instanceID];
    
    // Apply stamp transform
    float2 pos = in.position * stamp.size + stamp.position;
    
    // Apply rotation
    float c = cos(stamp.rotation);
    float s = sin(stamp.rotation);
    float2 rotated = float2(
        pos.x * c - pos.y * s,
        pos.x * s + pos.y * c
    );
    
    // Apply view transform
    float4 viewPos = uniforms.params.viewMatrix * float4(rotated, 0, 1);
    float4 clipPos = uniforms.params.projectionMatrix * viewPos;
    
    return clipPos;
}

vertex float4 vertex_composite(QuadVertex in [[stage_in]]) {
    return float4(in.position, 0, 1);
}

vertex float4 vertex_selection(QuadVertex in [[stage_in]]) {
    return float4(in.position, 0, 1);
}

// MARK: - Fragment Shaders

fragment float4 fragment_main(QuadVertex in [[stage_in]],
                             texture2d<float> canvasTexture [[texture(0)]],
                             sampler canvasSampler [[sampler(0)]],
                             constant RenderUniforms& uniforms [[buffer(1)]]) {
    
    // Sample canvas texture
    float2 texCoord = in.texCoord;
    float4 color = canvasTexture.sample(canvasSampler, texCoord);
    
    return color;
}

fragment float4 fragment_brush(QuadVertex in [[stage_in]],
                              uint instanceID [[instance_id]],
                              constant BrushUniforms& uniforms [[buffer(1)]],
                              device StampInstance* instances [[buffer(2)]],
                              texture2d<float> shapeTexture [[texture(0)]],
                              texture2d<float> grainTexture [[texture(1)]],
                              sampler shapeSampler [[sampler(0)]],
                              sampler grainSampler [[sampler(1)]]) {
    
    StampInstance stamp = instances[instanceID];
    BrushParameters params = uniforms.params;
    
    // Get texture coordinates
    float2 texCoord = in.texCoord;
    
    // Sample shape texture
    float4 shapeColor = float4(1, 1, 1, 1);
    if (params.shapeSource > 0) {
        shapeColor = shapeTexture.sample(shapeSampler, texCoord);
    }
    
    // Sample grain texture
    float4 grainColor = float4(1, 1, 1, 1);
    if (params.grainSource > 0) {
        float2 grainCoord = texCoord * params.grainScale * params.grainZoom;
        grainColor = grainTexture.sample(grainSampler, grainCoord);
        
        // Apply grain blend mode
        grainColor = blendGrain(grainColor, shapeColor, params.grainBlendMode);
    }
    
    // Combine shape and grain
    float4 baseColor = shapeColor * grainColor;
    
    // Apply color dynamics
    float4 finalColor = applyColorDynamics(baseColor, stamp.color, params, stamp);
    
    // Apply opacity
    finalColor.a *= stamp.opacity;
    
    return finalColor;
}

fragment float4 fragment_composite(QuadVertex in [[stage_in]],
                                  texture2d<float> layerTexture [[texture(0)]],
                                  texture2d<float> maskTexture [[texture(1)]],
                                  sampler layerSampler [[sampler(0)]],
                                  sampler maskSampler [[sampler(1)]],
                                  constant uint& blendMode [[buffer(1)]],
                                  constant float& opacity [[buffer(2)]]) {
    
    float2 texCoord = in.texCoord;
    float4 layerColor = layerTexture.sample(layerSampler, texCoord);
    layerColor.a *= opacity;
    
    // Apply mask if present
    if (maskTexture.width > 0) {
        float mask = maskTexture.sample(maskSampler, texCoord).r;
        layerColor.a *= mask;
    }
    
    // Blend mode is applied in the render pipeline
    return layerColor;
}

fragment float4 fragment_selection(QuadVertex in [[stage_in]],
                                  texture2d<float> selectionTexture [[texture(0)]],
                                  sampler selectionSampler [[sampler(0)]]) {
    
    float2 texCoord = in.texCoord;
    float4 selectionColor = selectionTexture.sample(selectionSampler, texCoord);
    
    // Selection marching ants animation
    float time = selectionColor.r; // Use r channel for animation
    float pattern = sin(time * 20.0 + texCoord.x * 50.0 + texCoord.y * 50.0);
    
    float4 color = float4(0.0, 0.5, 1.0, 0.5);
    color.a *= abs(pattern) * 0.5 + 0.5;
    
    return color;
}

// MARK: - Compute Shaders

kernel void generateBrushStamps(uint stampID [[thread_position_in_grid]],
                               constant StampGenerationInput& input [[buffer(0)]],
                               device BrushStamp* output [[buffer(1)]],
                               constant BrushParameters& params [[buffer(2)]],
                               texture2d<float> shapeTexture [[texture(0)]],
                               texture2d<float> grainTexture [[texture(1)]]) {
    
    if (stampID >= input.stampCount) return;
    
    float t = input.stampCount == 1 ? 0.5 : float(stampID) / float(input.stampCount - 1);
    
    // Interpolate position
    float2 position = mix(input.startPoint.position, input.endPoint.position, t);
    
    // Interpolate pressure
    float pressure = mix(input.startPoint.pressure, input.endPoint.pressure, t);
    
    // Interpolate tilt
    float2 tilt = mix(input.startPoint.tilt, input.endPoint.tilt, t);
    
    // Interpolate azimuth
    float azimuth = mix(input.startPoint.azimuth, input.endPoint.azimuth, t);
    
    // Calculate size with pressure
    float size = params.maxSize * pressure * params.pressureSize;
    size = clamp(size, params.minSize, params.maxSize);
    
    // Calculate opacity
    float opacity = pressure * params.pressureOpacity;
    opacity = clamp(opacity, params.minOpacity, params.maxOpacity);
    
    // Calculate rotation
    float2 direction = input.endPoint.position - input.startPoint.position;
    float rotation = atan2(direction.y, direction.x) + params.shapeRotation;
    
    // Apply dynamics
    float velocity = mix(input.startPoint.velocity, input.endPoint.velocity, t);
    size *= 1.0 + velocity * params.speedSize;
    opacity *= 1.0 - velocity * params.speedOpacity;
    
    // Calculate color
    float4 color = input.color;
    if (params.stampColorJitter > 0) {
        // Random jitter (simplified - would use random in real implementation)
        color.rgb += params.stampColorJitter * float3(0.5, 0.5, 0.5);
    }
    
    if (params.colorPressure > 0) {
        color = mix(color, params.secondaryColor, pressure * params.colorPressure);
    }
    
    output[stampID] = BrushStamp(
        position: position,
        size: size,
        rotation: rotation,
        opacity: opacity,
        color: color,
        textureIndex: 0
    );
}

// MARK: - Adjustment Shaders

kernel void adjustment_gaussianBlur(uint2 gid [[thread_position_in_grid]],
                                   texture2d<float, access::read> inputTexture [[texture(0)]],
                                   texture2d<float, access::write> outputTexture [[texture(1)]],
                                   constant AdjustmentParameters& params [[buffer(0)]]) {
    
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) return;
    
    float radius = params.blurRadius;
    int kernelSize = int(ceil(radius * 3.0));
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    
    float4 sum = float4(0);
    float weightSum = 0.0;
    
    for (int x = -kernelSize; x <= kernelSize; x++) {
        for (int y = -kernelSize; y <= kernelSize; y++) {
            float2 offset = float2(x, y) * texelSize;
            float dist = length(offset);
            float weight = exp(-dist * dist / (2.0 * radius * radius));
            
            float2 sampleCoord = float2(gid) * texelSize + offset;
            sampleCoord = clamp(sampleCoord, 0.0, 1.0);
            
            float4 sample = inputTexture.read(uint2(sampleCoord * float2(inputTexture.get_width(), inputTexture.get_height())));
            sum += sample * weight;
            weightSum += weight;
        }
    }
    
    outputTexture.write(sum / weightSum, gid);
}

kernel void adjustment_motionBlur(uint2 gid [[thread_position_in_grid]],
                                 texture2d<float, access::read> inputTexture [[texture(0)]],
                                 texture2d<float, access::write> outputTexture [[texture(1)]],
                                 constant AdjustmentParameters& params [[buffer(0)]]) {
    
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) return;
    
    float radius = params.motionBlurRadius;
    float angle = params.motionBlurAngle;
    int samples = int(ceil(radius));
    
    float2 direction = float2(cos(angle), sin(angle));
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    
    float4 sum = float4(0);
    float weightSum = 0.0;
    
    for (int i = -samples; i <= samples; i++) {
        float t = float(i) / float(samples);
        float2 offset = direction * t * radius * texelSize;
        
        float2 sampleCoord = float2(gid) * texelSize + offset;
        sampleCoord = clamp(sampleCoord, 0.0, 1.0);
        
        float weight = 1.0 - abs(t) * 0.5;
        float4 sample = inputTexture.read(uint2(sampleCoord * float2(inputTexture.get_width(), inputTexture.get_height())));
        
        sum += sample * weight;
        weightSum += weight;
    }
    
    outputTexture.write(sum / weightSum, gid);
}

kernel void adjustment_sharpen(uint2 gid [[thread_position_in_grid]],
                              texture2d<float, access::read> inputTexture [[texture(0)]],
                              texture2d<float, access::write> outputTexture [[texture(1)]],
                              constant AdjustmentParameters& params [[buffer(0)]]) {
    
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) return;
    
    float amount = params.sharpenAmount;
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    
    float4 center = inputTexture.read(gid);
    float4 sum = float4(0);
    
    // 3x3 sharpen kernel
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            float weight = (x == 0 && y == 0) ? (1.0 + 8.0 * amount) : -amount;
            uint2 coord = clamp(gid + uint2(x, y), uint2(0), uint2(inputTexture.get_width() - 1, inputTexture.get_height() - 1));
            sum += inputTexture.read(coord) * weight;
        }
    }
    
    outputTexture.write(sum, gid);
}

kernel void adjustment_colorBalance(uint2 gid [[thread_position_in_grid]],
                                   texture2d<float, access::read> inputTexture [[texture(0)]],
                                   texture2d<float, access::write> outputTexture [[texture(1)]],
                                   constant AdjustmentParameters& params [[buffer(0)]]) {
    
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) return;
    
    float4 color = inputTexture.read(gid);
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    
    float3 shadows = params.shadows;
    float3 midtones = params.midtones;
    float3 highlights = params.highlights;
    
    // Simple color balance
    float3 adjusted = color.rgb;
    
    if (luminance < 0.33) {
        adjusted += shadows * (1.0 - luminance * 3.0);
    } else if (luminance < 0.66) {
        adjusted += midtones * (1.0 - abs(luminance - 0.5) * 6.0);
    } else {
        adjusted += highlights * ((luminance - 0.66) * 3.0);
    }
    
    if (params.preserveLuminosity) {
        float newLuminance = dot(adjusted, float3(0.2126, 0.7152, 0.0722));
        adjusted = adjusted * (luminance / max(newLuminance, 0.001));
    }
    
    outputTexture.write(float4(adjusted, color.a), gid);
}

kernel void adjustment_curves(uint2 gid [[thread_position_in_grid]],
                             texture2d<float, access::read> inputTexture [[texture(0)]],
                             texture2d<float, access::write> outputTexture [[texture(1)]],
                             constant AdjustmentParameters& params [[buffer(0)]]) {
    
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) return;
    
    float4 color = inputTexture.read(gid);
    
    // Apply curve lookup (simplified - would use texture lookup for full 256-point curve)
    float r = color.r;
    float g = color.g;
    float b = color.b;
    float a = color.a;
    
    // Simple gamma-like curve
    r = pow(r, 1.0 / max(params.curvePoints[0], 0.01));
    g = pow(g, 1.0 / max(params.curvePoints[1], 0.01));
    b = pow(b, 1.0 / max(params.curvePoints[2], 0.01));
    
    outputTexture.write(float4(r, g, b, a), gid);
}

kernel void adjustment_hueSaturationBrightness(uint2 gid [[thread_position_in_grid]],
                                              texture2d<float, access::read> inputTexture [[texture(0)]],
                                              texture2d<float, access::write> outputTexture [[texture(1)]],
                                              constant AdjustmentParameters& params [[buffer(0)]]) {
    
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) return;
    
    float4 color = inputTexture.read(gid);
    float3 rgb = color.rgb;
    
    // Convert to HSV
    float h, s, v;
    float cmax = fmax(rgb.r, fmax(rgb.g, rgb.b));
    float cmin = fmin(rgb.r, fmin(rgb.g, rgb.b));
    float delta = cmax - cmin;
    
    v = cmax;
    s = cmax == 0 ? 0 : delta / cmax;
    
    if (delta == 0) {
        h = 0;
    } else if (cmax == rgb.r) {
        h = 60 * fmod((rgb.g - rgb.b) / delta, 6);
    } else if (cmax == rgb.g) {
        h = 60 * ((rgb.b - rgb.r) / delta + 2);
    } else {
        h = 60 * ((rgb.r - rgb.g) / delta + 4);
    }
    if (h < 0) h += 360;
    
    // Apply adjustments
    h = fmod(h + params.hueShift, 360);
    s = clamp(s + params.saturationShift, 0, 1);
    v = clamp(v + params.brightnessShift, 0, 1);
    
    // Colorize
    if (params.colorize) {
        h = params.colorizeHue;
        s = params.colorizeSaturation;
    }
    
    // Convert back to RGB
    float c = v * s;
    float x = c * (1 - fabs(fmod(h / 60.0, 2) - 1));
    float m = v - c;
    
    float3 newRgb;
    if (h < 60) newRgb = float3(c, x, 0);
    else if (h < 120) newRgb = float3(x, c, 0);
    else if (h < 180) newRgb = float3(0, c, x);
    else if (h < 240) newRgb = float3(0, x, c);
    else if (h < 300) newRgb = float3(x, 0, c);
    else newRgb = float3(c, 0, x);
    
    newRgb += m;
    
    if (params.colorize) {
        // Use colorize hue/saturation but preserve value
    }
    
    outputTexture.write(float4(newRgb, color.a), gid);
}

kernel void adjustment_recolor(uint2 gid [[thread_position_in_grid]],
                              texture2d<float, access::read> inputTexture [[texture(0)]],
                              texture2d<float, access::write> outputTexture [[texture(1)]],
                              constant AdjustmentParameters& params [[buffer(0)]]) {
    
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) return;
    
    float4 color = inputTexture.read(gid);
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    
    float3 recolorColor = params.recolorColor.rgb;
    float3 result = recolorColor * luminance;
    
    if (params.recolorMode == 1) { // Multiply
        result = color.rgb * recolorColor;
    } else if (params.recolorMode == 2) { // Screen
        result = 1.0 - (1.0 - color.rgb) * (1.0 - recolorColor);
    }
    
    outputTexture.write(float4(result, color.a), gid);
}

// MARK: - Blend Functions

float4 blendGrain(float4 grain, float4 base, uint blendMode) {
    float3 g = grain.rgb;
    float3 b = base.rgb;
    float3 result;
    
    switch (blendMode) {
        case GPUBlendMode.multiply:
            result = g * b;
            break;
        case GPUBlendMode.screen:
            result = 1.0 - (1.0 - g) * (1.0 - b);
            break;
        case GPUBlendMode.overlay:
            result = b < 0.5 ? 2.0 * g * b : 1.0 - 2.0 * (1.0 - g) * (1.0 - b);
            break;
        default:
            result = g;
    }
    
    return float4(result, grain.a);
}

float4 blendLayers(float4 src, float4 dst, uint blendMode) {
    float3 s = src.rgb;
    float3 d = dst.rgb;
    float3 result;
    
    switch (blendMode) {
        case GPUBlendMode.normal:
            result = s;
            break;
        case GPUBlendMode.multiply:
            result = s * d;
            break;
        case GPUBlendMode.screen:
            result = 1.0 - (1.0 - s) * (1.0 - d);
            break;
        case GPUBlendMode.overlay:
            result = d < 0.5 ? 2.0 * s * d : 1.0 - 2.0 * (1.0 - s) * (1.0 - d);
            break;
        case GPUBlendMode.softLight:
            result = d < 0.5 ? d - (1.0 - 2.0 * d) * s * (1.0 - s) : d + (2.0 * d - 1.0) * (s - d * d);
            break;
        case GPUBlendMode.hardLight:
            result = s < 0.5 ? 2.0 * s * d : 1.0 - 2.0 * (1.0 - s) * (1.0 - d);
            break;
        case GPUBlendMode.colorDodge:
            result = s == 1.0 ? 1.0 : min(1.0, d / (1.0 - s));
            break;
        case GPUBlendMode.colorBurn:
            result = s == 0.0 ? 0.0 : 1.0 - min(1.0, (1.0 - d) / s);
            break;
        case GPUBlendMode.darken:
            result = min(s, d);
            break;
        case GPUBlendMode.lighten:
            result = max(s, d);
            break;
        case GPUBlendMode.difference:
            result = abs(d - s);
            break;
        case GPUBlendMode.exclusion:
            result = s + d - 2.0 * s * d;
            break;
        default:
            result = s;
    }
    
    // Alpha compositing
    float a = src.a + dst.a * (1.0 - src.a);
    return float4(result, a);
}

float4 applyColorDynamics(float4 baseColor, float4 stampColor, BrushParameters params, StampInstance stamp) {
    float4 result = baseColor * stampColor;
    
    // Secondary color mix
    if (params.colorPressure > 0) {
        result = mix(result, params.secondaryColor, stamp.color.w * params.colorPressure);
    }
    
    // Saturation
    if (params.saturation != 0) {
        float luminance = dot(result.rgb, float3(0.2126, 0.7152, 0.0722));
        result.rgb = mix(float3(luminance), result.rgb, 1.0 + params.saturation);
    }
    
    // Brightness
    if (params.brightness != 0) {
        result.rgb += params.brightness;
    }
    
    // Purity
    if (params.purity != 0) {
        float maxC = fmax(result.r, fmax(result.g, result.b));
        float minC = fmin(result.r, fmin(result.g, result.b));
        float3 gray = float3((maxC + minC) * 0.5);
        result.rgb = mix(result.rgb, gray, params.purity);
    }
    
    return result;
}

// MARK: - Tile-based Rendering

struct TileData {
    uint2 origin;
    uint2 size;
    bool dirty;
};

kernel void renderTile(uint2 gid [[thread_position_in_grid]],
                      constant TileData& tile [[buffer(0)]],
                      device float4* tileBuffer [[buffer(1)]],
                      texture2d<float, access::read> layerTexture [[texture(0)]],
                      sampler layerSampler [[sampler(0)]]) {
    
    uint2 texCoord = tile.origin + gid;
    
    if (texCoord.x >= tile.origin.x + tile.size.x || texCoord.y >= tile.origin.y + tile.size.y) return;
    
    float2 uv = float2(texCoord) / float2(layerTexture.get_width(), layerTexture.get_height());
    tileBuffer[gid.y * tile.size.x + gid.x] = layerTexture.sample(layerSampler, uv);
}

// MARK: - Helpers

float clamp(float value, float min, float max) {
    return fmax(min, fmin(max, value));
}

float2 clamp(float2 value, float min, float max) {
    return fmax(float2(min), fmin(float2(max), value));
}

float mix(float a, float b, float t) {
    return a + (b - a) * t;
}

float2 mix(float2 a, float2 b, float t) {
    return a + (b - a) * t;
}

float4 mix(float4 a, float4 b, float t) {
    return a + (b - a) * t;
}

float length(float2 v) {
    return sqrt(v.x * v.x + v.y * v.y);
}

float dot(float3 a, float3 b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

float fmod(float a, float b) {
    return a - b * floor(a / b);
}

float fmax(float a, float b) {
    return a > b ? a : b;
}

float fmin(float a, float b) {
    return a < b ? a : b;
}

float abs(float a) {
    return a < 0 ? -a : a;
}

float float2(float2 v) { return v.x; } // Helper for swizzle
float float3(float3 v) { return v.x; }

// StampGenerationInput struct for compute shader
struct StampGenerationInput {
    StrokePoint startPoint;
    StrokePoint endPoint;
    BrushParameters params;
    float4 color;
    uint stampCount;
    uint2 canvasSize;
};

// AdjustmentParameters struct
struct AdjustmentParameters {
    // Common
    float intensity;
    uint blendMode;
    
    // Gaussian Blur
    float blurRadius;
    
    // Motion Blur
    float motionBlurRadius;
    float motionBlurAngle;
    
    // Perspective Blur
    float perspectiveBlurRadius;
    float2 perspectiveBlurCenter;
    float perspectiveBlurFocalDistance;
    
    // Sharpen
    float sharpenAmount;
    float sharpenRadius;
    
    // Noise
    float noiseAmount;
    uint noiseType;
    
    // Color Balance
    float3 shadows;
    float3 midtones;
    float3 highlights;
    bool preserveLuminosity;
    
    // Curves
    float curvePoints[256 * 4];
    
    // Hue/Saturation/Brightness
    float hueShift;
    float saturationShift;
    float brightnessShift;
    bool colorize;
    float colorizeHue;
    float colorizeSaturation;
    
    // Gradient Map
    float4 gradientColors[32];
    float gradientPositions[32];
    uint gradientMode;
    bool dither;
    
    // Recolor
    float4 recolorColor;
    uint recolorMode;
    
    // Liquify
    float2 liquifyMesh[100];
    float liquifyStrength;
    float liquifySize;
    float liquifyPressure;
};