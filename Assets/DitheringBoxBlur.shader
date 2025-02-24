Shader "DitheringBoxBlur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Radius("Blur Size", float) = 0.2
        _Tilling("Tilling", float) = 16.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            // Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
            #pragma exclude_renderers gles
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Radius;
            float _Tilling;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            uint rand_xsm32(uint x)
            {
                x ^= x >> 16;
                x *= 0x21f0aaadu;
                x ^= x >> 15;
                x *= 0x735a2d97u;
                x ^= x >> 15;
                return x;
            }

            float gaussian_rand_approx(uint pos)	// max error of the resulting Gaussian distribution: 9.8e-3
            {
                float r = (float(rand_xsm32(pos)) - 2147483647.5) * 4.6566125e-10;		// r = ]-1 , 1[

                return 0.88622693f * sqrt(-log(1. - r*r)) * sign(r);		// gives a e^-x^2 distribution, [-3.54 , 3.54]
            }
            fixed4 frag (v2f i) : SV_Target
            {
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                fixed4 col = tex2D(_MainTex, i.uv);
                float rotation = 6.283;
                float3 color = 0.0;

                float2 srcRes = 1.0 / _ScreenParams.xy * 1;
                float4 tc = tex2D(_MainTex, screenUV + float2(0,1) * _Radius * srcRes);
                float4 bc = tex2D(_MainTex, screenUV + float2(0,-1) * _Radius * srcRes);
                float4 lc = tex2D(_MainTex, screenUV + float2(-1,0) * _Radius * srcRes);
                float4 rc = tex2D(_MainTex, screenUV + float2(1,0) * _Radius * srcRes);
                
                float gradX = lc.x - rc.x;
                float gradY = tc.x - bc.x;
                float2 gradVec = float2(gradX, gradY);
                gradVec = float2(1,1);

                float st = sin(_Time.y * 3);
                float nst = st * 0.5 + 0.5;
                float2 uv = screenUV * _Tilling;
                float2 gridPos = floor(uv);
                float2 subUV = frac(uv) * 2;
                int subX = floor(subUV.x);
                int subY = floor(subUV.y);
                
                float2x2 pattern = {
                    0.125, 0.375, 
                    0.625, 0.875 
                };

                float random = frac(sin(dot(gridPos + gradVec, float2(12.9898,78.233))) * 43758.5453);
                random = gaussian_rand_approx(random * 10);
                float threshold = pattern[subX][subY]; 
                float dither = frac(threshold + random * 0.3);

                // float threshold = pattern[subx][suby];
                // threshold = frac(threshold + dot(gridPos, float2(12.9898,78.233)) * 43758.5453);
                
                // float dither = step(threshold, .9 + nst * 0.1);
                
                // return dither;
                // return subUV.xyxy;
                // return dither;
                
                // float weight = 0;
                for(int i = 0; i < 4; ++i)
                {
                    float weight = i / 4.0;
                    float currentAngle = 1.57 * i + rotation;
                    float jitterRadius = _Radius * (0.8 + dither * 0.4) * 0.01;
                    float2 offset = float2(cos(currentAngle + dither), sin(currentAngle + dither)) * jitterRadius;
                    color += tex2D(_MainTex, screenUV + offset * gradVec * (length(gradVec)));
                }
                color += tex2D(_MainTex, screenUV);

                return float4(color * 1/5, 1.0);
            }
            ENDCG
        }
    }
}