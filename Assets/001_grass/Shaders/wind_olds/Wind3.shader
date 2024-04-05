

Shader "TPR/Wind3"
{

    Properties
    {
        //_TargetTex("目标 rt", 2D) = "white" {}
        // 1: One
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", float) = 1

        [Header(Wind)]
        _WindAIntensity("_WindAIntensity", Float) = 1
        _WindAFrequency("_WindAFrequency", Float) = 4
        _WindATiling("_WindATiling", Vector) = (0.1,0.1,0)
        _WindAWrap("_WindAWrap", Vector) = (0.5,0.5,0)

    }


    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue"     = "Transparent"
        }

        LOD 100


        Blend [_SrcBlend] [_DstBlend]
        ZTest   Always
        ZWrite  Off
		Cull    Off


        Pass
        {
            Name "tpr_unlit" 

            HLSLPROGRAM

            #pragma vertex      vert 
            #pragma fragment    frag 

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            //TEXTURE2D(_TargetTex);  SAMPLER(sampler_TargetTex);

            #define PI     3.1415926
            #define TWO_PI 6.2831852


            CBUFFER_START(UnityPerMaterial)

                float _WindAIntensity; // 草随风 摆动的幅度
                float _WindAFrequency; // 草随风 摆动的频率
                float2 _WindATiling;   // 
                float2 _WindAWrap;     // 

            CBUFFER_END



            struct Attributes
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };


            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD1;
            };


            // ================================================================================= // 

            // x 在区间[t1,t2] 中, 求区间[s1,s2] 中同比例的点的值;
            float remap( float t1, float t2, float s1, float s2, float x )
            {
                return ((x - t1) / (t2 - t1) * (s2 - s1) + s1);
            }

            



            // ================================================================================= // 


            // ----------------------------------- // 
            //     手动计算 随机值，暂用版本
            // ----------------------------------- // 

            // 通过此函数，可以获得 正确的 snoise
            // 可以简单理解为，为任意一个点p，生成一组随机值 float3 [-1,1]
            // 应该没有 normalized
            float3 hash_0( float3 p ) // replace this by something better. really. do
            {
                p = float3( dot(p,float3(127.1,311.7, 74.7)),
                            dot(p,float3(269.5,183.3,246.1)),
                            dot(p,float3(113.5,271.9,124.6)));

                return -1.0 + 2.0*frac(sin(p)*43758.5453123); // [-1,1]
            }


            // gradient noise
            // ret [-1, 1] 仅检测得知，不完全保证
            float gradientNoise3D( float3 pos_ )
            {

                float3 p = floor( pos_ );
                float3 w = frac(  pos_ ); // 就算参数是负数，也运行正常

                float3 u = w*w*w*(w*(w*6.0-15.0)+10.0);

                // gradients
                float3 ga = hash_0( p+float3(0.0,0.0,0.0) );
                float3 gb = hash_0( p+float3(1.0,0.0,0.0) );
                float3 gc = hash_0( p+float3(0.0,1.0,0.0) );
                float3 gd = hash_0( p+float3(1.0,1.0,0.0) );
                float3 ge = hash_0( p+float3(0.0,0.0,1.0) );
                float3 gf = hash_0( p+float3(1.0,0.0,1.0) );
                float3 gg = hash_0( p+float3(0.0,1.0,1.0) );
                float3 gh = hash_0( p+float3(1.0,1.0,1.0) );


                // projections
                float va = dot( ga, w-float3(0.0,0.0,0.0) );
                float vb = dot( gb, w-float3(1.0,0.0,0.0) );
                float vc = dot( gc, w-float3(0.0,1.0,0.0) );
                float vd = dot( gd, w-float3(1.0,1.0,0.0) );
                float ve = dot( ge, w-float3(0.0,0.0,1.0) );
                float vf = dot( gf, w-float3(1.0,0.0,1.0) );
                float vg = dot( gg, w-float3(0.0,1.0,1.0) );
                float vh = dot( gh, w-float3(1.0,1.0,1.0) );

                // interpolation
                return va + 
                    u.x*(vb-va) + 
                    u.y*(vc-va) + 
                    u.z*(ve-va) + 
                    u.x*u.y*(va-vb-vc+vd) + 
                    u.y*u.z*(va-vc-ve+vg) + 
                    u.z*u.x*(va-vb-ve+vf) + 
                    u.x*u.y*u.z*(-va+vb+vc-vd+ve-vf-vg+vh);
            }

            // ================================================================================= // 



            float calc_noise( float2 uv )
            {
                float2 pos = uv*2-1;
                float groundRadius = 5;
                pos *= groundRadius;  // [-groundRadius, groundRadius]

                float time = _Time.y * 1;
                float p = gradientNoise3D( float3( pos.x, pos.y, time ) ); // 猜测 [-1,1], 但不适合 remap 到 [0,1], 效果不理想;
                return p;
            }


            float kkk( float2 uv )
            {

                float noise = calc_noise( uv );

                





            }






   



           
            // ================================================================================= // 

            Varyings vert( Attributes input )
            {
                Varyings output = (Varyings)0;
                output.positionHCS = TransformObjectToHClip( input.vertex.xyz ); 
                output.uv = input.uv;
                return output;
            }


            float4 frag( Varyings input ) : SV_Target
            {

                float t = _Time.y % 1000; // 约束精度;

                

                float u = input.uv.x * 1.0;
                float v = input.uv.y * 1.0;

                float2 uv2 = float2( u,v );


                //float time = calc_time();
                float k = calc_noise( uv2 );
                return float4( k, k, k, 1 );


            }

            ENDHLSL
        }
    }


}
