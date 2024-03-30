

Shader "TPR/Wind4"
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

            #include "../wind.hlsl"


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

            // // x 在区间[t1,t2] 中, 求区间[s1,s2] 中同比例的点的值;
            // float remap( float t1, float t2, float s1, float s2, float x )
            // {
            //     return ((x - t1) / (t2 - t1) * (s2 - s1) + s1);
            // }

            
           
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
                //float k = calc_noise( uv2 );
                //return float4( k, k, k, 1 );

                float k = calc_wind( uv2, 0 );// [-1,1]
                

                
                k = pow( 1- abs(k), 3);


                return float4( k, 0, 0, 1 );


            }

            ENDHLSL
        }
    }


}