Shader "FT Scene/Grass2"
{
    Properties
    {
        
       
        _NoiseColorTex("Noise Color Tex", 2D) = "white" {} // 草地杂色, 四方连续
        _GroundHeightTex("Ground Height Tex", 2D) = "white" {}
        _WheatTex("麦浪 Tex", 2D) = "white" {}

        _DirNormalTex("dir normal Tex", 2D) = "white" {}


        _UpColor("Up Color", Color) = (1,1,1,1)

        _HighLightColor("hight light Color", Color) = (1,1,1,1)

        _BottomColor("Bottom Color", Color) = (1,1,1,1)


       
        _Gloss("Gloss", Range(1.0, 64.0)) = 20.0 // 控制 高光区域大小


        [Header(Grass Shape)]
        _GrassWidth("_GrassWidth", Float) = 1
        _GrassHeight("_GrassHeight", Float) = 3.5 // 草的高度

        _GroundGridSize("地面网格(正方形)边长", Float) = 11


        _wheatWaveGridSize("麦浪网格(正方形)边长", Float) = 12
        _wheatWaveDegree("麦浪方向夹角(0,360)", Range(0,360)) = 0
        _wheatWaveSpeed("麦浪运动速度", Float) = 1.5



        [HideInInspector]_PivotPosWS("_PivotPosWS", Vector) = (0,0,0,0)
        [HideInInspector]_BoundSize("_BoundSize", Vector) = (1,1,0)

        [HideInInspector]_GroundRadiusWS ("Ground Radius", Float) = 50 // 草地半径; //超出此半径的草全被剔除;
    }



    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"}

        Pass
        {
            Name "Grass2" 

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
                
                half3 color        : COLOR;
                float2 uv           : TEXCOORD1;
                float4 rootPosWS   : TEXCOORD2;    // xyz:rootPosWS;  w:posOS.y [0,1]
                float4 shadowCoord  : TEXCOORD3;
                float3 viewWS       : TEXCOORD4;
                float3 normalWS     : TEXCOORD5;
            };

            CBUFFER_START(UnityPerMaterial)

                float3 _PivotPosWS; // 草地 gameobj 的 posWS
                float2 _BoundSize;  // 草地 gameobj 的 localScale {x,z}

                float _GrassWidth;  // 草 宽度缩放
                float _GrassHeight; // 草 高度缩放
               
             
                float4 _GroundHeightTex_ST;
                float4 _NoiseColorTex_ST;
                float4 _WheatTex_ST;
                float4 _DirNormalTex_ST;


                float3 _UpColor;
                float3 _HighLightColor;

                float3 _BottomColor;

                float _GroundGridSize;

                float _wheatWaveGridSize;
                float _wheatWaveDegree;
                float _wheatWaveSpeed;

                float _Gloss;


                float _GroundRadiusWS; // 草地半径; 和 posws 同坐标比例; 超出此半径的草全被剔除;

                // 所有草的 posWS, 按照 cell 的次序排序
                StructuredBuffer<float3> _AllInstancesTransformBuffer; // 有 11mb 大;

                // 本帧可见的 每个草叶子 的 idx 值; (在 _AllInstancesTransformBuffer 内的 idx 值)
                StructuredBuffer<uint> _VisibleInstanceOnlyTransformIDBuffer;

            CBUFFER_END



            //-----------
         
            sampler2D _GroundHeightTex;
            sampler2D _NoiseColorTex;
            sampler2D _WheatTex;
            sampler2D _DirNormalTex;


            
        
            // random01_: 区间[0.0,1.0]
            float3 Rotate( float3 localPosWS, float random01_ ) 
            {
                float deg = remap( -1, 1, -45, 45, random01_ );
                float2 ret = Rotate2D( localPosWS.xz, deg );
                return float3( ret.x, localPosWS.y, ret.y );
            }





            // 一个草叶子( 4个三角形构成的菱形) 上的一个顶点:
            // 一个草叶子的每个顶点在调用本函数时, 它们的 instanceID 都是相同的
            Varyings vert(Attributes IN, uint instanceID : SV_InstanceID)
            {
                Varyings OUT = (Varyings)0;

                // ======================= 各项功能开关, >0 表示开启 =============================
                float isUse_Wind = 1;           // 是否启用 风
                float isUse_GroundHeight = -1;   // 是否使用  _GroundHeightTex 里的数据来制作 整块起伏的 草地样貌
                float isFarGrassFatter = -1;   

                float isUseDir = 1;


                // ====================================================

                // 本颗草 的 root posWS; (就是草最下方的那个点)
                float3 grassRootPosWS = _AllInstancesTransformBuffer[_VisibleInstanceOnlyTransformIDBuffer[instanceID]];

                float2 groundUV = frac( grassRootPosWS.xz / _GroundGridSize );

                float3 viewWS = _WorldSpaceCameraPos - grassRootPosWS;// 草->camera
                float ViewWSLength = length(viewWS); // 草 到 相机距离

                float grassNoise = hash12(grassRootPosWS.xz); // [0,1]
                grassNoise = grassNoise * 2 - 1; // [-1,1]


                //-- 基于高度信息的三种 曲线分布
                float y1 = IN.positionOS.y;
                float y2 = y1 * y1;
                float y3 = y1 * y1 * y1;



                float3 noiseColor = tex2Dlod(_NoiseColorTex, float4(TRANSFORM_TEX(grassRootPosWS.xz,_NoiseColorTex),0,0)).rgb;//sample mip 0 only
                float noiseColorGray = saturate( dot(noiseColor.rgb, float3(0.299, 0.587, 0.114)) ); // 明度值;
                float heightWeight = lerp( 0.8, 1.5, noiseColorGray ); // 越亮的草越高
                heightWeight *= lerp( 1, 1.5, noiseColor.r ); // 越红的草更高

                
            
                //=========================================
                // UNITY_MATRIX_V == Camera.worldToCameraMatrix; 
                // 从中取出 camera 的 三个轴方向:
                float3 cameraRightWS    = UNITY_MATRIX_V[0].xyz;    //UNITY_MATRIX_V[0].xyz == world space camera Right Dir
                float3 cameraUpWS       = UNITY_MATRIX_V[1].xyz;    //UNITY_MATRIX_V[1].xyz == world space camera Up Dir
                float3 cameraForwardWS  = -UNITY_MATRIX_V[2].xyz;   //UNITY_MATRIX_V[2].xyz == world space camera Forward Dir * -1  (因为 view-space 为右手坐标系,是反的)
                //---

                
                // --- right:
                //float3 rightWS = normalize( Rotate3D_yAxis( cameraRightWS, _wheatWaveDegree ));
                float3 rightWS = cameraRightWS;
                //float3 rightWS = float3( -1,0,0 );

                //float xzDeg = remap( -1, 1, -45, 45, grassNoise );
                // float2 ret = Rotate2D( localPosWS.xz, _wheatWaveDegree );


                // --- up:
                //float3 upWS = normalize( lerp( cameraUpWS, float3(0,1,0), 0.8 )); // cameraUp 和 纯Up 的插值, 一个尽可能朝向天空的方向;
                float3 upWS = float3(0,1,0);

                // --- grassWidth: 
                float grassWidth = _GrassWidth;
                //grassWidth = grassWidth * (sin(grassRootPosWS.x*95.4643 + grassRootPosWS.z) * 0.45 + 0.55); // 让每颗草的宽度在 [0.1,1] 之间随机; (-这部分具体怎么计算无所谓-)

                if( isFarGrassFatter > 0 )
                {
                    // 让那些远离 camera 的三角形变得更胖些, 以此来遮挡远处的 小于一个像素的三角形 带来的 闪烁问题;
                    grassWidth += max(0, ViewWSLength * 0.015); // (-这部分具体怎么计算无所谓-)
                }

                // --- grassHeight:
                float grassHeight = _GrassHeight * heightWeight;

                if(isUse_GroundHeight > 0)
                {
                    float height1 = tex2Dlod(_GroundHeightTex, float4(TRANSFORM_TEX(groundUV,_GroundHeightTex),0,0)).r;//sample mip 0 only
                    grassHeight *= remap( 0, 1, 0.8, 1.7, height1 );
                }


                if( isUseDir > 0 ) 
                {
                    float3 tangent = float3( 1, 0, 0 );
                    float3 bitangent = float3( 0, 0, 1 );
                    float3x3 tangentTransform = float3x3(tangent, bitangent, float3(0,1,0));


                    float3 normalMapVal = UnpackNormal( tex2Dlod(_DirNormalTex, float4(TRANSFORM_TEX(groundUV,_DirNormalTex),0,0)).rgba);                

                    float3 normalDir = normalize(mul(normalMapVal, tangentTransform)); // 噪波法线1(世界空间法线)
                    
                    // !! 基于 normalDir 做点扰动

                    upWS = lerp(upWS, SafeNormalize(normalDir), 0.6);



                    
                    // 让草变得弯曲:
                    upWS.x *= y2; 
                    upWS.z *= y2; 
                }



                {




                }




                // ----------------------------------------------
                // --- localPosWS: (在 World-Space 中, 从 grassRoot 到 本顶点 的距离偏移):
                // (注: IN.positionOS 是本顶点在 Object-Space 里的 local pos)
                float3 localPosWS = (IN.positionOS.x * rightWS * grassWidth) + (IN.positionOS.y * upWS * grassHeight);
                // ---  本顶点的真正的 posWS:
                float3 posWS = grassRootPosWS + localPosWS;

              

                

                // =========== 风 =============
                if(isUse_Wind > 0.0)
                {
                    float2 pp = (grassRootPosWS.xz/_GroundRadiusWS) * 0.5 + 0.5;

                    float wind = calc_wind( pp, grassNoise ); // [-1,1]
                    wind = remap( -1, 1, -0.08, 0.25, wind ); // 微风, 微微向画面右侧摆动, 允许向左回弹;
                

                    float windWeight = grassNoise;
                    windWeight = saturate( pow(abs(windWeight), 2) );
                    windWeight = remap( 0, 1, 0.1, 1, windWeight );

                    wind = wind * windWeight * global_wind_weight();

                    
                    //这里使用了个方法, 以让风只影响 三角形的 上顶点;
                    wind *= y2; 
                    float3 windDir = GetWindDir( _wheatWaveDegree-90, _wheatWaveSpeed ); // 风吹方向与 麦浪方向相同
                    float3 windOffset = windDir * wind;
                    posWS.xyz += windOffset;
                }



             


                // ============================ color ===========================        
                float3 upColor = lerp( _UpColor, noiseColor, 0.8 );
                //upColor = lerp( _BottomColor, upColor, 0.5 * (1-distancePct2) );
                upColor = lerp( _BottomColor, upColor, 0.5 );
              
                

                // 简单补充: 草从下往上渐变色;
                float3 lightingResult = lerp( _BottomColor, upColor, IN.positionOS.y * IN.positionOS.y );

                // ========
                OUT.positionCS = TransformWorldToHClip(posWS);
                OUT.color = lightingResult;
                OUT.rootPosWS.xyz = grassRootPosWS;
                OUT.rootPosWS.w = y1;
                OUT.uv = IN.uv;
                OUT.shadowCoord = TransformWorldToShadowCoord(posWS);
                OUT.viewWS = _WorldSpaceCameraPos - posWS;
                OUT.normalWS = float3( 0,0, -1 );
                return OUT;
            }


            half4 frag(Varyings IN) : SV_Target
            {
                // ======================= 各项功能开关, >0 表示开启 =============================
                float isUseWheatWave = 1;


                // --------------------
                float time = _Time.y % 1000; // 约束精度;
                float2 uv = IN.uv; // 手写在叶子顶点内的 uv值;
                float3 rootPosWS = IN.rootPosWS.xyz; 
                float2 groundUV = frac( rootPosWS.xz / _GroundGridSize );
                float y1 = IN.rootPosWS.w;
                float y2 = y1 * y1;
                float y3 = y1 * y1 * y1;
                float y4 = y2 * y2;


              


                //------------- shadow ---------------
                Light mainLight = GetMainLight(IN.shadowCoord);
                half shadow = mainLight.shadowAttenuation; // light:1; shadow:0

                // ----------------------------




                // ------------ Specular ----------------

                float3 viewDirWS = normalize(IN.viewWS);
                float3 halfDir = normalize(viewDirWS + normalize(mainLight.direction));
                float  specular = pow( max(0.0, dot(normalize(IN.normalWS),halfDir)), _Gloss);
                specular = remap( 0, 1, 0, specular, y4);

                float3 sColor = float3(1,1,1) * specular;

                //return half4( specular, specular, specular, 1); 



                // -------------- wheat wave --------------
                float2 wheatUV = GetWheatWaveUV( rootPosWS, _wheatWaveDegree, _wheatWaveGridSize, time, _wheatWaveSpeed );


                //float height = tex2Dlod(_GroundHeightTex, float4(TRANSFORM_TEX(groundUV,_GroundHeightTex),0,0)).r; //sample mip 0 only
                float wheatVal = tex2Dlod(_WheatTex, float4(TRANSFORM_TEX(wheatUV,_WheatTex),0,0)).r; //sample mip 0 only

                


                //float3 lightColor = lerp( IN.color, _HighLightColor, remap(0, 1, 0, 0.5, wheatVal) );
                float3 lightColor = IN.color;

                if(isUseWheatWave > 0)
                {
                    lightColor = lerp( lightColor, _HighLightColor, remap(0, 1, 0, 0.5, wheatVal) );
                }



                float3 bottomColor = lerp( IN.color, _BottomColor, 0.5 );

                float3 c = lerp( bottomColor, lightColor, y3 );

                c = lerp( _BottomColor, c, remap(0, 1, 0.3, 1, shadow) ); // 此法不好

                //c += sColor;

                //return half4( height, height, height, 1); 
                //return half4( 0, uv.y * uv.y * uv.y , 0, 1); 
                //return half4(IN.color,1); 


                float2 dir = Degree2Dir(_wheatWaveDegree);
                //return half4( dir.xy*0.5+0.5, 0,1);


                return half4(c,1);
            }



            ENDHLSL
        }
    }
}