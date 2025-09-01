// Conway's Game of Life, with trails and colors added.
// by Ed Mackey and other contributors.
// License: https://creativecommons.org/publicdomain/zero/1.0/

import playground;

const static int STATE_LIVE = -1;
const static int STATE_INORGANIC = 0;
const static int STATE_JUST_DIED = 1;
const static int STATE_MAX_DECAY = 500;
const static float STARTUP_TIME = 4.0;

[playground::BLACK_SCREEN(1.0, 1.0)]
RWTexture2D<int> tex_life;

[playground::BLACK_SCREEN(1.0, 1.0)]
RWTexture2D<int> tex_previous;

[playground::TIME]
uniform float time;

[playground::FRAME_ID]
uniform float frame;

[playground::MOUSE_POSITION]
uniform float4 mousePosition;

[playground::SLIDER(16.0, 1.5, 100.0)]
uniform float brush_radius;

[playground::SLIDER(1.0, 1.0, 10.0)]
uniform float zoom;

[playground::COLOR_PICK(0.4, 1.0, 0.2)]
uniform float3 live_color;
[playground::COLOR_PICK(0.35, 0.19, 0.19)]
uniform float3 died_color;
[playground::COLOR_PICK(0.0, 0.0, 0.25)]
uniform float3 decayed_color;

const static float3 inorganic_color = float3(0.0, 0.0, 0.0); // inorganic dead (never was live)

uint getState(int2 pos, int2 imageSize)
{
    pos += imageSize;
    pos.x = pos.x % imageSize.x;
    pos.y = pos.y % imageSize.y;

    uint state = tex_previous[pos];

    return state;
}

void setState(int2 pos, int2 imageSize, uint state)
{
    pos += imageSize;
    pos.x = pos.x % imageSize.x;
    pos.y = pos.y % imageSize.y;

    tex_life[pos] = state;
}

void setRandomState(int2 pos, int2 imageSize)
{
    float rnd1 = fract(sin(dot(pos + time * 0.001, float2(14.9898,78.233))) * 43758.5453) % 1.0;

    setState(pos, imageSize, (rnd1 > 0.5) ? STATE_LIVE : STATE_JUST_DIED);
}

[shader("compute")]
[numthreads(16, 16, 1)]
[playground::CALL::SIZE_OF("tex_life")]
void game(uint2 dispatchThreadId: SV_DispatchThreadID)
{
    uint imageW1;
    uint imageH1;
    tex_life.GetDimensions(imageW1, imageH1);

    uint imageW2;
    uint imageH2;
    tex_previous.GetDimensions(imageW2, imageH2);

    int2 pos = int2(dispatchThreadId);
    int2 imageSize = int2(min(imageW1, imageW2), min(imageH1, imageH2));

    if (mousePosition.z < 0)
    {
        float2 offset = float2(imageSize - imageSize / zoom) * 0.5;
        float2 mouse = float2(abs(mousePosition.xy)) / zoom + offset;

        if (distance(pos, mouse) < brush_radius)
        {
            setRandomState(pos, imageSize);
            return;
        }
    }

    if (time < STARTUP_TIME && frame > 1)
    {
        float radius = min(imageSize.x, imageSize.y) * 0.4375 * (1.0 - time / STARTUP_TIME);
        if (distance(pos, imageSize * 0.5) < radius)
        {
            setRandomState(pos, imageSize);
            return;
        }
    }

    int sum = 0;
    if (getState(pos + int2(-1, -1), imageSize) == STATE_LIVE) ++sum;
    if (getState(pos + int2(-1, 0), imageSize) == STATE_LIVE) ++sum;
    if (getState(pos + int2(-1, 1), imageSize) == STATE_LIVE) ++sum;
    if (getState(pos + int2(1, -1), imageSize) == STATE_LIVE) ++sum;
    if (getState(pos + int2(1, 0), imageSize) == STATE_LIVE) ++sum;
    if (getState(pos + int2(1, 1), imageSize) == STATE_LIVE) ++sum;
    if (getState(pos + int2(0, -1), imageSize) == STATE_LIVE) ++sum;
    if (getState(pos + int2(0, 1), imageSize) == STATE_LIVE) ++sum;

    uint state = getState(pos, imageSize);

    if (state == STATE_LIVE)
    {
        // I'm alive. Can I stay that way?
        if (sum < 2 || sum > 3)
        {
            // Nope.
            state = STATE_JUST_DIED;
        }
    }
    else
    {
        // I'm some kind of dead.
        if (sum == 3)
        {
            // I'm back alive!
            state = STATE_LIVE;
        }
        else if (state >= STATE_JUST_DIED && state < STATE_MAX_DECAY)
        {
            ++state;
        }
    }

    // Always set a state, so previous state is copied to current.
    setState(pos, imageSize, state);
}

[shader("compute")]
[numthreads(16, 16, 1)]
[playground::CALL::SIZE_OF("tex_life")]
void currentToPrevious(uint2 dispatchThreadId: SV_DispatchThreadID)
{
    // Copy all current states to previous

    uint imageW1;
    uint imageH1;
    tex_life.GetDimensions(imageW1, imageH1);

    uint imageW2;
    uint imageH2;
    tex_previous.GetDimensions(imageW2, imageH2);

    int2 pos = int2(dispatchThreadId);
    int2 imageSize = int2(min(imageW1, imageW2), min(imageH1, imageH2));

    if (pos.x > imageSize.x || pos.y > imageSize.y)
        return;

    tex_previous[pos] = tex_life[pos];
}

float4 imageMain(uint2 dispatchThreadID, int2 screenSize)
{
    uint imageW;
    uint imageH;
    tex_life.GetDimensions(imageW, imageH);

    float2 offset = float2(screenSize - screenSize / zoom) * 0.5;
    uint2 scaled = (uint2)floor(float2(dispatchThreadID.xy) / zoom + offset);
    uint2 flipped = uint2(scaled.x, imageH - scaled.y);

    int2 imageSize = int2(imageW, imageH);
    int state = getState(flipped, imageSize);

    if (state == STATE_LIVE)
        return float4(live_color, 1.0);

    if (state <= STATE_INORGANIC)
        return float4(inorganic_color, 1.0);

    float3 color = lerp(died_color, decayed_color, float(state - 1) / (STATE_MAX_DECAY - 1));
    return float4(color, 1.0);
}
