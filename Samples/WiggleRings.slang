// Original by "Trisomie21"
// Ported from: https://glslsandbox.com/e#5398.8
// License: https://creativecommons.org/publicdomain/zero/1.0/ (as far as anyone knows)

import playground;

[playground::TIME]
uniform float time;

float4 imageMain(uint2 dispatchThreadId, int2 screenSize)
{
    float scale = screenSize.y / 100.0;
    float ring = 50.0;
    float radius = screenSize.x*1.0;
    float gap = scale*.5;
    float2 pos = float2(dispatchThreadId) - screenSize.xy*.5;

    float d = length(pos);

    // Create the wiggle
    d += (sin(pos.y*0.25/scale+time)*sin(pos.x*0.25/scale+time*.5))*scale*2.0;

    // Compute the distance to the closest ring
    float v = fmod(d + radius/(ring*2.0), radius/ring);
    v = abs(v - radius/(ring*2.0));

    v = clamp(v-gap, 0.0, 1.0);

    d /= radius;
    float3 m = fract((d-1.0)*float3(ring*-.5, -ring, ring*.25)*0.5);

    return float4( m*v, 1.0 );
}
