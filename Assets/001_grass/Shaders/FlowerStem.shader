/* 
    绘制花杆
*/
Shader "FT Scene/FlowerStem"
{
    Properties
    {
    
   
  
        _ShadowColor("Shadow Color", Color) = (1,1,1,1)
        _DownColor("Down Color", Color) = (1,1,1,1)
        _UpColor("Up Color", Color) = (1,1,1,1)
        

     


       
        [Header(Grass Shape)]
        _Grass("x:叶宽; y:叶高;", Vector) = ( 0.05, 0.7, 0, 0 )
  
        _GridSizes("网格(正方形)边长: x:地面网格, y:麦浪网格", Vector) = (11, 15, 0, 0)

    
        _wheatWaveDegree("麦浪方向夹角(0,360)", Range(0,360)) = 0
        _Wind("x:麦浪运动速度(可正负); y:风力大小;", Vector) = ( 1.5, 2, 0, 0 )

        //---
        [HideInInspector]_PivotPosWS("_PivotPosWS", Vector) = (0,0,0,0)
        [HideInInspector]_BoundSize("_BoundSize", Vector) = (1,1,0)
        [HideInInspector]_GroundRadiusWS ("Ground Radius", Float) = 50 // 草地半径; //超出此半径的草全被剔除;
    }



    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"}

        Pass
        {
            Name "FlowerStem" 

            Cull Back
            ZTest Less
            ZWrite On
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // -------------------------------------
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            //#pragma multi_compile _ _SHADOWS_SOFT

            // -------------------------------------
            // Unity defined keywords
            //#pragma multi_compile_fog
            // -------------------------------------

            // 必须支持 SV_InstanceID input system value
            #pragma require instancing


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            //#include "gradientNoise3D.hlsl"
            #include "../Shaders/wind.hlsl"
            #include "Grass2.hlsl"


            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                float2 uv           : TEXCOORD1;
                float4 rootPosWS   : TEXCOORD2;    // xyz:rootPosWS;  w:posOS.y [0,1]
                float4 shadowCoord  : TEXCOORD3;
                float3 normalWS     : TEXCOORD4;
            };

            CBUFFER_START(UnityPerMaterial)
                float3 _PivotPosWS; // 草地 gameobj 的 posWS
                float2 _BoundSize;  // 草地 gameobj 的 localScale {x,z}
                //---
               
          
                float4 _DirNormalTex_ST;
                //---
                float4 _Grass;
                float4 _GridSizes;

                
                //---
                float3 _ShadowColor;
                float3 _DownColor;
                float3 _UpColor;
          
                //---
                float _wheatWaveDegree;
                float4 _Wind;

                float _GroundRadiusWS; // 草地半径; 和 posws 同坐标比例; 超出此半径的草全被剔除;

                
                StructuredBuffer<float4> _AllInstancesRootPosWSBuffer;
                StructuredBuffer<float4> _AllInstancesDirWSBuffer;

               

            CBUFFER_END

            //-----------
         

  
            
    

            // 一个草叶子( 4个三角形构成的菱形) 上的一个顶点:
            // 一个草叶子的每个顶点在调用本函数时, 它们的 instanceID 都是相同的
            Varyings vert(Attributes IN, uint instanceID : SV_InstanceID)
            {
                Varyings OUT = (Varyings)0;

                // ======================= 各项功能开关, >0 表示开启 =============================
                float isUse_Wind = 1;           // 是否启用 风
    
        


                // ====================================================
                float3 rootPosWS = _AllInstancesRootPosWSBuffer[instanceID].xyz;
                float  stemLen   = _AllInstancesRootPosWSBuffer[instanceID].w;
                float3 dirWS        = _AllInstancesDirWSBuffer[instanceID].xyz;
                float  localScale   = _AllInstancesDirWSBuffer[instanceID].w;

              

                float grassNoise = hash12(rootPosWS.xz); // [0,1]
                grassNoise = grassNoise * 2 - 1; // [-1,1]


                //-- 基于高度信息的三种 曲线分布
                float y1 = IN.positionOS.y;
                float y2 = y1 * y1;
                float y3 = y1 * y1 * y1;

            
                //=========================================
                // UNITY_MATRIX_V == Camera.worldToCameraMatrix; 
                // 从中取出 camera 的 三个轴方向:
                float3 cameraRightWS    = UNITY_MATRIX_V[0].xyz;    //UNITY_MATRIX_V[0].xyz == world space camera Right Dir
                float3 cameraUpWS       = UNITY_MATRIX_V[1].xyz;    //UNITY_MATRIX_V[1].xyz == world space camera Up Dir
                float3 cameraForwardWS  = -UNITY_MATRIX_V[2].xyz;   //UNITY_MATRIX_V[2].xyz == world space camera Forward Dir * -1  (因为 view-space 为右手坐标系,是反的)
                //---
                
                // --- right:
                float3 rightWS = cameraRightWS;

                // --- up:
                float3 upWS = dirWS;

                // --- grassWidth: 
                float grassWidth = _Grass.x;                
                // --- grassHeight:
                float grassHeight = stemLen;

                // ----------------------------------------------
                // --- localPosWS: (在 World-Space 中, 从 grassRoot 到 本顶点 的距离偏移):
                // (注: IN.positionOS 是本顶点在 Object-Space 里的 local pos)
                float3 localPosWS = (IN.positionOS.x * rightWS * grassWidth) + (IN.positionOS.y * upWS * grassHeight);
                // ---  本顶点的真正的 posWS:
                float3 posWS = rootPosWS + localPosWS;


                // =========== 风 =============
                if(isUse_Wind > 0.0)
                {
                    float2 pp = (rootPosWS.xz/_GroundRadiusWS) * 0.5 + 0.5;

                    float wind = calc_wind( pp, grassNoise ); // [-1,1]
                    wind = remap( -1, 1, -0.08, 0.25, wind ); // 微风, 微微向画面右侧摆动, 允许向左回弹;
                
                    float windWeight = grassNoise;
                    windWeight = saturate( pow(abs(windWeight), 2) );
                    windWeight = remap( 0, 1, 0.1, 1, windWeight );

                    wind = wind * windWeight * global_wind_weight() * _Wind.y;
                    
                    //这里使用了个方法, 以让风只影响 三角形的 上顶点;
                    wind *= y3; // 让草变得柔软 
                    float3 windDir = GetWindDir( _wheatWaveDegree-90, _Wind.x ); // 风吹方向与 麦浪方向相同
                    float3 windOffset = windDir * wind;
                    posWS.xyz += windOffset;
                }

                // ========
                OUT.positionCS = TransformWorldToHClip(posWS);
                OUT.rootPosWS.xyz = rootPosWS;
                OUT.rootPosWS.w = y1;
                OUT.uv = IN.uv;
                OUT.shadowCoord = TransformWorldToShadowCoord(rootPosWS);
                OUT.normalWS = float3( 0,0, -1 );
                return OUT;
            }


            half4 frag(Varyings IN) : SV_Target
            {
                // ======================= 各项功能开关, >0 表示开启 =============================
                //float isUseWheatWave = 1;

                // --------------------
                float time = _Time.y % 1000; // 约束精度;
                float2 uv = IN.uv; // 手写在叶子顶点内的 uv值;
                float3 rootPosWS = IN.rootPosWS.xyz; 
                float groundGridSize = _GridSizes.x;
                float wheatWaveGridSize = _GridSizes.y;
                float y1 = IN.rootPosWS.w;
                float y2 = y1 * y1;
                float y3 = y1 * y1 * y1;
                float y4 = y2 * y2;

                // ----------------------------
                float3 upColor = _UpColor;
                

                // //------------- shadow ---------------
                Light mainLight = GetMainLight(IN.shadowCoord);
                half shadow = mainLight.shadowAttenuation; // light:1; shadow:0
                // //---
                half3 c = lerp( _DownColor, upColor, y2 ); // 叶子上下分色
                c = lerp( _ShadowColor, c, shadow ); // 给阴影处上色
                return half4( c,1);
            }

            ENDHLSL
        }
    }
}