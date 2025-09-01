// Alan's Sandbox, ported to Slang
// Originally from http://glslsandbox.com/e#23079.18
// by Alan Mackey and other contributors.
// License: https://creativecommons.org/publicdomain/zero/1.0/

import playground;

[playground::BLACK_SCREEN(2.0, 2.0)]
RWTexture2D<float> tex_current;

[playground::BLACK_SCREEN(2.0, 2.0)]
RWTexture2D<float> tex_previous;

[playground::TIME]
uniform float time;

[playground::MOUSE_POSITION]
uniform float4 mousePosition;

// Material alpha values
const static float aVoid = 0.9;
const static float aSand = 0.8;
const static float aPlant = 0.7;
const static float aFire = 0.6;
const static float aSmoke = 0.2;
const static float aWater = 0.5;

float4 getColor(int2 iPos, int2 imageSize)
{
    // NOTE: Gets color from previous, not current.

    iPos = clamp(iPos, int2(0), imageSize - 1);
    return float4(
        tex_previous[iPos],
        tex_previous[iPos + int2(imageSize.x, 0)],
        tex_previous[iPos + int2(0, imageSize.y)],
        tex_previous[iPos + imageSize]);
}

void setColor(int2 iPos, int2 imageSize, float4 color)
{
    // NOTE: Sets current color, not previous.

    iPos = clamp(iPos, int2(0), imageSize - 1);
    tex_current[iPos] = color.r;
    tex_current[iPos + int2(imageSize.x, 0)] = color.g;
    tex_current[iPos + int2(0, imageSize.y)] = color.b;
    tex_current[iPos + imageSize] = color.a;
}

[shader("compute")]
[numthreads(16, 16, 1)]
[playground::CALL::SIZE_OF("tex_current")]
void currentToPrevious(uint2 dispatchThreadId: SV_DispatchThreadID)
{
    // Copy all current colors to previous

    uint imageW;
    uint imageH;
    tex_previous.GetDimensions(imageW, imageH);

    int2 iPos = int2(dispatchThreadId);
    int2 imageSize = int2(imageW, imageH);

    if (iPos.x > imageSize.x || iPos.y > imageSize.y)
        return;

    tex_previous[iPos] = tex_current[iPos];
}

bool is_(float4 px, float material) {
    // Test for specific material
    return (abs(px.a - material) < 0.045);
}

bool isSolid(float4 px) {
    // Test for any solid material
    return is_(px, 1.0) || is_(px, aSand) || is_(px, aPlant) || is_(px, aWater);
}

float4 px(int dx, int dy, int2 iPos, int2 imageSize) {
    // Fetch pixel RGBA at relative location
    int2 posDelta = iPos - int2(dx, dy);
    if ((posDelta.x < 0.0) || (posDelta.y < 0.0) || (posDelta.x >= imageSize.x) || (posDelta.y >= imageSize.y)) {
        return float4(0.0);
    }
    return getColor(posDelta, imageSize);
}

float rand(int seed, int2 iPos) {
    // Random float based on time, location and seed
    return fract(sin(time*23.254 + float(seed)*438.5345 - iPos.x*37.2342 + iPos.y * 73.25423)*3756.234);
}

float sRand(int seed, int2 iPos) {
    // Random float based on location and seed but not time
    return fract(sin(float(seed)*438.5345 - iPos.x*37.2342 + iPos.y * 73.25423)*3756.234);
}

float tRand() {
    // Random float based only on time
    return fract((sin(time*0.006458)+sin(time*0.09234)+sin(time*0.7454))*953.234);
}

float xRand(int2 iPos) {
    // Random float based on time and X coord
    return fract(sin(time*23.254 + iPos.x*37.2342)*3756.234);
}

float yRand(int2 iPos) {
    // Random float based on time and Y coord
    return fract(sin(time*23.254 + iPos.y*37.2342)*3756.234);
}

float3 FireColor(int2 iPos) {
    return float3(0.5, 0.1, 0.03) * (10.0 * pow(rand(0,iPos), 2.0));
}

float3 WaterColor(float2 pos, int2 imageSize) {
    pos.y *= float(imageSize.y) / imageSize.x;
    return float3(0.5, 0.7, 0.9) * (0.8 + 0.3 * (sin(length(pos)*250.0-time*8.0) + sin(length(1.0-pos)*222.0-time*7.0))) + float3(0.0, 0.1, 0.4);
}

float4 imageAdvance(int2 iPos, int2 imageSize)
{
    float4 fragColor = float4(0.0, 0.0, 0.0, 1.0);

    float2 pos = float2(iPos) / imageSize;
    float2 mouse = float2(mousePosition.x, imageSize.y - mousePosition.y - 1) / imageSize;
    float2 mDist = pos-mouse;
    mDist.y *= float(imageSize.y)/imageSize.x;
    float interfaceX = min(imageSize.x * 0.1, imageSize.y * 0.2);

    float4 here = px(0,0,iPos,imageSize);

    float4 material = getColor(int2(0), imageSize);
    float brushSizeA = getColor(int2(1,0), imageSize).a;
    if ((brushSizeA < 0.01) || (brushSizeA > 0.99)) {brushSizeA = 0.25;}
    float brushSize = brushSizeA * interfaceX / imageSize.x * 0.7;
    if (!(is_(material, aSand) || is_(material, aVoid) || is_(material, aPlant) || is_(material, aFire) || is_(material, aWater))) {
        material.a = aSand;
    }

    if ((iPos.x < interfaceX) || (iPos.y < 3.0) || (iPos.x >= imageSize.x-interfaceX) || (iPos.y >= imageSize.y-3.0)) {
        // This pixel is outside the game area

        if ((mouse.x * imageSize.x > imageSize.x - interfaceX) && (mouse.y > 0.01) && (mouse.y < 0.99)) {
            brushSizeA = 1.0-mouse.y;
            brushSize = brushSizeA * interfaceX / imageSize.x * 0.7;
        }

        float brushHere = interfaceX * 0.5 * (1.0-pos.y);
        if ((iPos.y < 3.0) || (iPos.y >= imageSize.y-3.0)) {brushHere = 0.0;}
        if (abs(iPos.x - (imageSize.x-interfaceX/2.0)) <= brushHere * 0.9) {fragColor.rgb = float3(0.1, 0.14, 0.25);}
        if (length(iPos.xy - float2(imageSize.x-interfaceX/2.0, imageSize.y * (1.0-brushSizeA))) < brushSizeA * interfaceX * 0.45) {
            fragColor.rgb = float3(1.0);
        }

        // Sand sample
        float2 sample =  float2(interfaceX * 0.5, imageSize.y - interfaceX * 0.5);
        float sampleDist = length(iPos.xy - sample);
        if (length(mouse*imageSize - sample) < interfaceX*0.4) {material.a = aSand;}
        if (sampleDist < interfaceX * 0.4) {
            fragColor.rgb = float3(0.8+0.2*sRand(1,iPos), 0.6+0.2*sRand(2,iPos), 0.1+0.2*sRand(5,iPos)) * (1.0 + 0.8 * (sRand(3,iPos) - sRand(7,iPos)));
        } else if (is_(material, aSand) && (sampleDist < interfaceX * 0.43)) {
            fragColor.rgb = float3(0.0, 0.8, 0.3);
        }

        // Void sample
        sample =  float2(interfaceX * 0.5, imageSize.y - interfaceX * 1.5);
        sampleDist = length(iPos.xy - sample);
        if (length(mouse*imageSize - sample) < interfaceX*0.4) {material.a = aVoid;}
        if (sampleDist < interfaceX * 0.4) {
            fragColor.rgb = float3(0.1, 0.7 - 0.6 * (1.0-(1.0-pos.y)*imageSize.y/interfaceX - sample.y/imageSize.y + 1.7), 0.8);
        } else if (is_(material, aVoid) && (sampleDist < interfaceX * 0.43)) {
            fragColor.rgb = float3(0.0, 0.8, 0.3);
        }

        // Plant sample
        sample =  float2(interfaceX * 0.5, imageSize.y - interfaceX * 2.5);
        sampleDist = length(iPos.xy - sample);
        if (length(mouse*imageSize - sample) < interfaceX*0.4) {material.a = aPlant;}
        if (sampleDist < interfaceX * 0.4) {
            fragColor.rgb = float3(0.2, 0.4, 0.1);
        } else if (is_(material, aPlant) && (sampleDist < interfaceX * 0.43)) {
            fragColor.rgb = float3(0.0, 0.8, 0.3);
        }

        // Fire sample
        sample =  float2(interfaceX * 0.5, imageSize.y - interfaceX * 3.5);
        sampleDist = length(iPos.xy - sample);
        if (length(mouse*imageSize - sample) < interfaceX*0.4) {material.a = aFire;}
        if (sampleDist < interfaceX * 0.4) {
            fragColor.rgb = FireColor(iPos);
        } else if (is_(material, aFire) && (sampleDist < interfaceX * 0.43)) {
            fragColor.rgb = float3(0.0, 0.8, 0.3);
        }

        // Water sample
        sample =  float2(interfaceX * 0.5, imageSize.y - interfaceX * 4.5);
        sampleDist = length(iPos.xy - sample);
        if (length(mouse*imageSize - sample) < interfaceX*0.4) {material.a = aWater;}
        if (sampleDist < interfaceX * 0.4) {
            fragColor.rgb = WaterColor(pos, imageSize);
        } else if (is_(material, aWater) && (sampleDist < interfaceX * 0.43)) {
            fragColor.rgb = float3(0.0, 0.8, 0.3);
        }

        // Write status pixels
        if ((iPos.x == 0) && (iPos.y == 0)) {
            fragColor.a = material.a;
        } else if ((iPos.x == 1) && (iPos.y == 0)) {
            fragColor.a = brushSizeA;
        }
        return fragColor;
    }

    if (mousePosition.z < 0.0 &&    // Mouse button is pressed
        mousePosition.x > interfaceX && mousePosition.x < imageSize.x-interfaceX &&  // Mouse in game area
        length(mDist) < brushSize)  // Mouse is within brush size
    {
        if (is_(material, aSand) && (rand(1,iPos) < 0.1)) {
            // This pixel is being filled with sand
            fragColor.rgb = float3(0.8+0.2*rand(1,iPos), 0.6+0.2*rand(2,iPos), 0.1+0.2*rand(5,iPos)) * (1.0 + 0.8 * (rand(3,iPos) - rand(7,iPos)));
            fragColor.a = aSand;
            return fragColor;
        } else if (is_(material, aPlant)) {
            float ang = tRand() * 3.14159 * 2.0;
            float2 leaf = float2(cos(ang)*mDist.x - sin(ang)*mDist.y,
                     sin(ang)*mDist.x + cos(ang)*mDist.y);
            leaf.x *= 3.0;
            if (length(leaf) < brushSize) {
                float edge = pow(1.0-length(leaf)/brushSize, 0.3) * 0.5 + 0.75;
                fragColor.rgb = float3(0.2, 0.4, 0.1) * (1.0 + 0.5*tRand()) * edge;
                fragColor.a = aPlant;
                return fragColor;
            }
        } else if (is_(material, aVoid) && !is_(here, aVoid)) {
            // This pixel is being erased
            fragColor.rgb = float3(1);
            fragColor.a = aVoid;
            return fragColor;
        } else if (is_(material, aFire) && (rand(1,iPos) < 0.02) && !is_(here, aSand)) {
            // This pixel is being ignited
            fragColor.rgb = float3(1.0);
            fragColor.a = aFire;
            return fragColor;
        } else if (is_(material, aWater) && (rand(1,iPos) < 0.02))  {
            // Drop a water pixel here
            fragColor.rgb = WaterColor(pos, imageSize);
            fragColor.a = aWater;
            return fragColor;
        }
    }

    int sandSlide = (tRand() > 0.5) ? -1 : 1;
    int waterSlide = (yRand(iPos) > 0.5) ? -1 : 1;
    float4 below = px(0,1,iPos,imageSize);
    float4 above = px(0,-1,iPos,imageSize);
    float4 belowSide = px(sandSlide,1,iPos,imageSize);
    float4 aboveSide = px(-sandSlide,-1,iPos,imageSize);

    if (is_(here, aPlant)) {
        float fireCheck = 0.0;
        if (is_(above, aFire)) {fireCheck += (rand(11,iPos) > 0.8) ? 1.0 : 0.1;}
        if (is_(below, aFire)) {fireCheck += (rand(12,iPos) > 0.4) ? 1.0 : 0.1;}
        if (is_(px(1,0,iPos,imageSize), aFire)) {fireCheck += (rand(13,iPos) > 0.6) ? 1.0 : 0.1;}
        if (is_(px(-1,0,iPos,imageSize), aFire)) {fireCheck += (rand(14,iPos) > 0.6) ? 1.0 : 0.1;}
        if (fireCheck >= 1.0) {
            fragColor.rgb = FireColor(iPos);
            fragColor.a = aFire;
            return fragColor;
        } else if (fireCheck > 0.0) {
            here.rgb *= 0.8;
        }
        // This is a stable plant pixel
        fragColor = here;
        return fragColor;
    } else if (is_(here, aFire)) {
        if (rand(10,iPos) < 0.7) {
            fragColor.rgb = FireColor(iPos);
            fragColor.a = aFire;
            return fragColor;
        }
    } else if (is_(here, aSand)) {
        if (isSolid(below) && (isSolid(belowSide) || isSolid(px(sandSlide,0,iPos,imageSize)))) {
            if ((is_(below, aWater)) && (xRand(iPos) > 0.6)) {
                // Sand sinks in water
                fragColor.rgb = WaterColor(pos, imageSize);
                fragColor.a = aWater;
                return fragColor;
            }
            // This sand grain is at rest
            fragColor = here;
            return fragColor;
        }
    } else if (is_(here, aWater)) {
        if ((is_(above, aSand)) && (xRand(iPos) > 0.6)) {
            // Water floats in sand
            fragColor = above;
            return fragColor;
        }
        if (isSolid(below) && (isSolid(px(waterSlide,0,iPos,imageSize)) || isSolid(px(waterSlide,-1,iPos,imageSize)))) {
            float4 there = px(int(rand(3,iPos)*3.0)-1, int(rand(5,iPos)*3.0)-1,iPos,imageSize);
            if ((is_(there, aPlant)) && (rand(25,iPos) < 0.1)) {
                // Plant grows in water
                fragColor = there;
                fragColor.rgb *= 1.0 + 0.1 * rand(14,iPos) - 0.1 * rand(15,iPos);
                if ((fragColor.g < 0.1) || (fragColor.r > 0.9)) {
                    fragColor.rgb = float3(0.2, 0.4, 0.1);
                }
                return fragColor;
            }

            // This water particle is at rest
            fragColor.rgb = WaterColor(pos, imageSize);
            fragColor.a = aWater;
            return fragColor;
        }
    } else if (is_(here, aVoid) || is_(here, aSmoke)) {
        if (is_(above, aSand)) {
            // A sand grain is falling into this pixel
            fragColor = above;
            return fragColor;
        }
        if (is_(aboveSide, aSand) && isSolid(px(-sandSlide,0,iPos,imageSize)) && !isSolid(above)) {
            // A sand grain is sliding down a slope into this pixel
            fragColor = aboveSide;
            return fragColor;
        }
        if ( is_(above, aWater) ||
             (is_(px(-waterSlide,0,iPos,imageSize), aWater) && isSolid(px(-waterSlide,1,iPos,imageSize)) && !isSolid(above)) ) {
            // A water drop is going here
            fragColor.rgb = WaterColor(pos, imageSize);
            fragColor.a = aWater;
            return fragColor;
        }
        if (is_(below, aFire)) {
            // Fire is below this pixel; Propagate fire or smoke
            if (rand(5,iPos) < 0.4) {
                fragColor.rgb = FireColor(iPos);
                fragColor.a = aFire;
                return fragColor;
            }
            fragColor.rgb = float3(0.2);
            fragColor.a = aSmoke;
            return fragColor;
        }
        if (is_(below, aSmoke) && (rand(3,iPos) < 0.95)) {
            // Smoke is below this pixel; large chance for it to boil upwards
            fragColor.rgb = float3(0.2);
            fragColor.a = aSmoke;
            return fragColor;
        }
    }

    // This pixel is a void
    fragColor.rgb = float3(0.1, 0.7 - 0.6 * pos.y, 0.8);
    fragColor.a = aVoid;
    return fragColor;
}

float4 imageMain(uint2 dispatchThreadID, int2 screenSize)
{
    uint imageW1;
    uint imageH1;
    tex_current.GetDimensions(imageW1, imageH1);

    uint imageW2;
    uint imageH2;
    tex_previous.GetDimensions(imageW2, imageH2);

    int2 iPos = int2(dispatchThreadID);
    int2 imageSize = int2(min(imageW1, imageW2) / 2, min(imageH1, imageH2) / 2);
    imageSize = min(screenSize, imageSize);

    float4 fragColor = imageAdvance(iPos, imageSize);
    setColor(iPos, imageSize, fragColor);

    return float4(fragColor.rgb, 1.0);
}
