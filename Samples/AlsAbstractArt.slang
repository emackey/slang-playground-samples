// Based on Al's Abstract Art
// http://glslsandbox.com/e#375.15
// Imported from GLSL:
// https://docs.shader-slang.org/en/latest/coming-from-glsl.html
// by Alan Mackey and other contributors.
// License: https://creativecommons.org/publicdomain/zero/1.0/

import playground;

const static float BRUSH_RADIUS = 0.007;

[playground::BLACK_SCREEN(2.0, 1.0)]
RWTexture2D<float> tex_red;
[playground::BLACK_SCREEN(2.0, 1.0)]
RWTexture2D<float> tex_green;
[playground::BLACK_SCREEN(2.0, 1.0)]
RWTexture2D<float> tex_blue;

[playground::TIME]
uniform float time;

[playground::MOUSE_POSITION]
uniform float4 mousePosition;

float3 getColor(int2 pos, int2 imageSize)
{
    // NOTE: Gets color from previous, not current.

    pos = clamp(pos, int2(0), imageSize - 1) + int2(imageSize.x, 0);
    return float3(tex_red[pos], tex_green[pos], tex_blue[pos]);
}

void setColor(int2 pos, int2 imageSize, float3 color)
{
    // NOTE: Sets current color, not previous.

    pos = clamp(pos, int2(0), imageSize - 1);
    tex_red[pos] = color.x;
    tex_green[pos] = color.y;
    tex_blue[pos] = color.z;
}

[shader("compute")]
[numthreads(16, 16, 1)]
[playground::CALL::SIZE_OF("tex_red")]
void currentToPrevious(uint2 dispatchThreadId: SV_DispatchThreadID)
{
    // Copy all current colors to previous

    uint imageW;
    uint imageH;
    tex_red.GetDimensions(imageW, imageH);

    int2 pos = int2(dispatchThreadId);
    int2 imageSize = int2(imageW / 2, imageH);

    if (pos.x > imageSize.x || pos.y > imageSize.y)
        return;

    int2 prev = pos + int2(imageSize.x, 0);
    tex_red[prev] = tex_red[pos];
    tex_green[prev] = tex_green[pos];
    tex_blue[prev] = tex_blue[pos];
}

float mod(float x, float y)
{
    return x - y * floor(x/y);
}

float4 imageMain(uint2 dispatchThreadID, int2 screenSize)
{
    uint imageW;
    uint imageH;
    tex_red.GetDimensions(imageW, imageH);

    int2 pos = int2(dispatchThreadID);
    int2 imageSize = int2(imageW / 2, imageH);
    float3 me = getColor(pos, imageSize);

    float2 position = float2(dispatchThreadID) / screenSize;
    float2 mouse = float2(mousePosition.x, screenSize.y - mousePosition.y - 1) / screenSize;

    float2 rnd = float2(mod(fract(sin(dot(position + time * 0.001, float2(14.9898,78.233))) * 43758.5453), 1.0),
                 mod(fract(sin(dot(position + time * 0.001, float2(24.9898,44.233))) * 27458.5453), 1.0));
    float2 nudge = float2(12.0 + 10.0 * cos(time * 0.03775),
                   12.0 + 10.0 * cos(time * 0.02246));
    float2 rate = -0.005 + 0.02 * (0.5 + 0.5 * cos(nudge * (position.yx - 0.5) + 0.5 + time * float2(0.137, 0.262)));

    if (length(position-mouse) < BRUSH_RADIUS)
    {
        me.r = 0.5+0.5*sin(time * 1.234542);
        me.g = 0.5+0.5*sin(3.0 + time * 1.64242);
        me.b = 0.5+0.5*sin(4.0 + time * 1.444242);
    } else {
        rate *= 6.0 * abs(0.5 - mouse);
        rate += 0.5 * rate.yx;
        float2 multiplier = 1.0 - rate;
        float2 jitter = 1.1 / float2(screenSize);
        float2 offset = (rate * mouse) - (jitter * 0.5);
        int2 sourcePos = int2(round((position * multiplier + offset + jitter * rnd) * imageSize));
        float3 source = getColor(sourcePos, imageSize);

        me = me * 0.05 + source * 0.95;
    }

    setColor(pos, imageSize, me);
    return float4(me, 1.0);
}
