// Draws swirling lines, emulating something like a Spirograph (tm)
// by Alan Mackey
// License: https://creativecommons.org/publicdomain/zero/1.0/

import playground;

[playground::BLACK_SCREEN(2.0, 2.0)]
RWTexture2D<float> tex_current;

[playground::BLACK_SCREEN(2.0, 2.0)]
RWTexture2D<float> tex_previous;

[playground::FRAME_ID]
uniform float frame_id;

[playground::MOUSE_POSITION]
uniform float4 mousePosition;

[playground::SLIDER(15.5, 1, 50)]
uniform float rate1;

[playground::SLIDER(0.21, 0, 1)]
uniform float size1;

[playground::SLIDER(44.8, 1, 50)]
uniform float rate2;

[playground::SLIDER(0.085, 0, 1)]
uniform float size2;

[playground::SLIDER(27, 1, 50)]
uniform float rate3;

[playground::SLIDER(0, 0, 1)]
uniform float size3;


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

void setColor(int2 iPos, int2 imageSize, float4 in_color)
{
    // NOTE: Sets current color, not previous.

    float4 color = clamp(in_color, 0, 1);
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

float2 cpos( float ang, float dist) {
	return float2(sin(ang)*dist, cos(ang)*dist);
}

float line ( float2 start, float2 end, int2 iPos, int2 imageSize ) {
	float thickness = 1.3;
	float soft = thickness * 1.5;
	float core = thickness - soft;

	float2 c = float2(0.5, 0.5*imageSize.y/imageSize.x);

	float2 a = (start+c)*imageSize.x;
	float2 l = (end + c)*imageSize.x;

	float2 P = iPos.xy;
	float2 aP = P-a;
	float2 al = l-a;

	float3 aP3 = float3(aP, 0.0);
	float3 al3 = float3(al, 0.0);
	float q = length(cross(aP3,al3))/length(al3);

	float d = q;
	if ( dot(al, aP) <= 0.0 ) { // before start
               d = distance(P, a);
	}
        else if ( dot(al, al) <= dot(al, aP) ) { // after end
               d = distance(P, l);
	}
	return (thickness-d) / soft;
	return min(1.0, max(0.0, ((d - core) / soft) * (step(d, thickness))));
}

static const int dots = 35;
float4 imageAdvance(int2 iPos, int2 imageSize)
{
    float4 fragColor = getColor(iPos, imageSize);
    if (fragColor.a < 0.5) {
		fragColor.rgba = float4(1, 1, 1, 1);
	}
    fragColor.rgb += 1.1 / 255.0;

	float2 sp = iPos - 0.5;
	sp.y *= imageSize.y / imageSize.x;

	float range = 500;

	for (int n=0; n<dots; n++) {
		float tfA = frame_id * 0.001 + n * 3.24523;
		float2 dpA = cpos(tfA*rate1, size1);
		dpA += cpos(tfA*rate2, size2);
		dpA += cpos(tfA*rate3, size3);

		float tfB = (frame_id + 1.9) * 0.001 + n * 3.24523;
		float2 dpB = cpos(tfB*rate1, size1);
		dpB += cpos(tfB*rate2, size2);
		dpB += cpos(tfB*rate3, size3);

		float d = line(dpA, dpB, iPos, imageSize);
		if (d > 0.0) {
			fragColor.rgb -= d * 0.75;
		}
	}

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
