

Shader "TPR/Wind"
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

            float sdf_circle( float2 p, float r )
            {
                return length(p) - r;
            }


            float meta( float2 p, float r ) 
            {
                //return r / dot(p,p);
                float k = r / max(0.01, length(p));

                //k = min( k, 1 );
                return k;
            }


            // meta ball
            float sdf_distance( float2 uv )
            {
                // float d1 = sdf_circle( uv - float2(-0.5,0.3), 0.2 );
                // float d2 = sdf_circle( uv - float2(0.1,-1), 0.4 );
                // float d3 = sdf_circle( uv - float2(-0.1,0), 0.1 );
                // return min(min(d1, d2), d3 );

                // float d1 = sdf_circle( uv - float2(0.3,0.6), 0.2 );
                // float d2 = sdf_circle( uv - float2(0.6,0.2), 0.3 );

                // return min( d1, d2 );
                // ----------

                float t = sin( _Time.y * 10);

                t = remap( -1, 1, 0.1, 0.2, t );

                float r1 = 0.2 + t;
                float r2 = 0.2 + t;
                float r3 = 0.2 + t;
                

                float d =   meta( uv - float2(0.3,0.8), r1 ) *
                            meta( uv - float2(0.2,0.2), r2 ) *
                            meta( uv - float2(0.6,0.2), r3 );

                return d;


            }

            // 测试 metaball 的风
            float kk_3( float2 uv )
            {
                float sdf_val = sdf_distance(uv);

                float k = sin( sdf_val*10 + _Time.y*2 );
                k = 1-abs(k);
                //k = k*0.5+0.5;

                return k;

            }


            float calc_k_1( float2 uv, float2 centerPos ) 
            {
                float distance = length(uv - centerPos );

                float time = sin( _Time.y * TWO_PI );
                time = remap( -1, 1, 1.1, 1.2, time );                
                time = time + _Time.y;

                float k = sin( (distance + time*0.5 ) * 10 );
                k = pow(1-abs(k), 2); // 
                return k;
            }

            float calc_k_2( float2 uv, float2 centerPos ) 
            {
                float distance = length(uv - centerPos );
                float k = sin( (distance - _Time.y*0.8 + 3 ) * 5 );
                k = pow(1-abs(k), 2); // 
                return k;
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

                float t2 = t * 0.1;

                float u = input.uv.x * 1.0;
                float v = input.uv.y * 1.0;

                float2 uv2 = float2( u,v );


                //return float4( u,v, 0, 1 );

                // float2 centerPos2_A = float2( 0,0 ); // 基于 uv 坐标系的

                // float distance_A = length(uv2 - centerPos2_A);
                // float k1 = sin( (distance_A + _Time.y ) * 10 );
                // k1 = pow(1-abs(k1), 2); // 


                float k1 = calc_k_1( uv2, float2(0,0) ); // 基于 uv 坐标系的
                //float k2 = calc_k_2( uv2, float2( -0.5, 1.5) ); // 基于 uv 坐标系的
                //float f = max( k1, k2 );

                float kk3 = kk_3( uv2 );

                return float4( kk3, 0, 0, 1 );


                /*
                    float2 uv1 = float2( sin( (u+t2)*6.28 * 2 ), cos( (v+t2)*6.28 * 2 ) );
                    float2 uv2 = float2( sin( (u+t2)*6.28 * 5 ), cos( (v+t2)*6.28 * 5 ) );

                    
                    float val1 = 0.5 * (uv1.x + uv1.y); // 0.8
                    float val2 = 0.2 * (uv2.x + uv2.y); // 0.3

                    //float cosU1 = 1 * cos( (u+t2) * 6.28 * 5.0 );


                    t += val1 + val2;
                    //t += val1 + val2 + cosU1;
                    //t =  cosU1;

                    float s = sin(t);
                    float c = cos(t);
            
                    s = s * 0.5 + 0.5; // [0,1]
                    c = c * 0.5 + 0.5; // [0,1]

                    float k = 1.0-max(s,c);
                    float k2 = max(s,c);



                    
                    // //float4 c = SAMPLE_TEXTURE2D( _TargetTex, sampler_TargetTex, input.uv );

                    // float2 pos2 = input.uv * 40;


                    // float wind = 0;
                    // // wind += (

                    // //     sin(_Time.y * _WindAFrequency + pos2.x * _WindATiling.x + pos2.y * _WindATiling.y) * _WindAWrap.x + _WindAWrap.y
                    
                    // // ) * _WindAIntensity; // [0,1]

                    // wind += sin( pos2.x * pos2.x + pos2.y ) * 0.5 + 0.5;
                    



                    return float4( k, 0, 0, 1 );     
                */





            }

            ENDHLSL
        }
    }


}
