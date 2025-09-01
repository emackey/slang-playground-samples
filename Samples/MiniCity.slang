// Ported from: https://glslsandbox.com/e#22430.0
// License: https://creativecommons.org/publicdomain/zero/1.0/ (as far as anyone knows)

import playground;

[playground::TIME]
uniform float time;

float rand(float seed) {
	seed = fmod(seed * 61.6, 12.38) + 5.16;
	return fract(7153.1 * sin(pow(seed, 2.)));
}

float4 imageMain(uint2 dispatchThreadId, int2 screenSize)
{
	float2 r = float2(screenSize);
	float2 p = float2(dispatchThreadId) / r;

	// Sky gradient
	float3 sky = float3(0.9, .86, .8);

	float3 col = sky;

	// Rows of buildings
	for (int i = 26; i >= 2; i--) {
		float row = float(i);
		float which_building = p.x * (8.2 + pow(row, 1.1) * 4.) + time * 0.2 / (2. - 2./(row*row)) + 712.9 * row;
		float height = rand(floor(which_building)) * pow(0.9, row+1.) + row * 0.05 - 0.3;
		float building_x = fract(which_building);
		float building_y = (height - p.y) * row;
		if (building_y > 0.) {
			// Hit building
			col = sky * pow(0.9, 23. - row);
			// Lights
			float rlight = rand(floor(which_building + building_y * 1.)); // This glitched out but I like it now.
			if (abs(building_x - 0.5) < 0.4 && fract(building_y * 4.) > 0.2) {
				col += float3(0.9, 0.9, .5+0.4*cos(row)) * pow(0.8, row) * rlight;
			}
		}
	}
    return float4(col, 1.0);
}
