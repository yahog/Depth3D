 ////--------//
 ///**DLAA**///
 //--------////

 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 //* Directionally localized antialiasing.                                     																										*//
 //* For Reshade 3.0																																								*//
 //* --------------------------																																						*//
 //* This work is licensed under a Creative Commons Attribution 3.0 Unported License.																								*//
 //* So you are free to share, modify and adapt it for your needs, and even use it for commercial use.																				*//
 //* I would also love to hear about a project you are using it with.																												*//
 //* https://creativecommons.org/licenses/by/3.0/us/																																*//
 //*																																												*//
 //* Have fun,																																										*//
 //* Jose Negrete AKA BlueSkyDefender																																				*//
 //*																																												*//
 //* http://and.intercon.ru/releases/talks/dlaagdc2011/																																*//	
 //* ---------------------------------																																				*//
 //*                                                                            																									*//
 //* 																																												*//
 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

uniform bool Debug_View <
	ui_label = "Debug View";
	ui_tooltip = "To view Edge Detect working on, movie piture & ect.";
> = false;

uniform int Luminace_Selection <
	ui_type = "combo";
	ui_items = "Green Channel Luminace\0RGB Luminace\0";
	ui_label = "Luminace Selection";
	ui_tooltip = "Luminace color selection Green to RGB.";
> = 0;

uniform float Luminosity_Intensity <
	ui_type = "drag";
	ui_min = 1.0; ui_max = 10.0;
	ui_label = "Luminosity Intensity";
	ui_tooltip = "This adjust the Edge Detection Luminace seeking value.\n"
				 "When in doubt leave it at default.\n"
				 "Number 1.0 is default.";
> = 1.0;

/////////////////////////////////////////////////////D3D Starts Here/////////////////////////////////////////////////////////////////
#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)
#define lambda 3.0f
#define epsilon 0.1f

texture BackBufferTex : COLOR;

sampler BackBuffer 
	{ 
		Texture = BackBufferTex;
	};
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Luminosity Intensity
float3 LI(in float3 value)
{	
	//Luminosity Controll from 0.1 to 1.0 
	//If GGG value of 0.333, 0.333, 0.333 is about right for Green channel. 
	//If RGB channels are used as luminosity 0.299, 0.587, 0.114
	float Lum;
	if (Luminace_Selection == 1)
	{
		Lum = dot(value.xyz, float3(0.299*Luminosity_Intensity, 0.587*Luminosity_Intensity, 0.114*Luminosity_Intensity));
	}
	else
	{
		Lum = dot(value.xyz, float3(0.333*Luminosity_Intensity, 0.333*Luminosity_Intensity, 0.333*Luminosity_Intensity));
	}
	
	return Lum;
}

//Short Edge Filter http://and.intercon.ru/releases/talks/dlaagdc2011/slides/#slide43
float4 shortEdge(float2 texcoord)
{
	float4 Center, HNeg, HPos, VNeg, VPos, Done;
	
	//5 bi-linear samples cross
	Center = tex2D(BackBuffer, texcoord);    
	HNeg   = tex2D(BackBuffer, texcoord + float2(-pix.x,  0.0) );
	HPos   = tex2D(BackBuffer, texcoord + float2( pix.x,  0.0) ); 
	VNeg   = tex2D(BackBuffer, texcoord + float2( 0.0, -pix.y) ); 
	VPos   = tex2D(BackBuffer, texcoord + float2( 0.0,  pix.y) );
	
	//Combine horizontal and vertical blurs together
	float4 combH   = HNeg + HPos;
	float4 combV   = VNeg + VPos;
	
	//Bi-directional anti-aliasing using *only* HORIZONTAL blur and horizontal edge detection
	float4 CenterDiffH = abs( combH - 2.0 * Center ) * 0.5;  
	float4 CenterDiffV = abs( combH - 2.0 * Center ) * 0.5;
	
	//Edge detection
	float EdgeLumH    = LI( CenterDiffH.rgb );
	float EdgeLumV    = LI( CenterDiffV.rgb );
		
	//Blur
	float4 blurredH   = ( combH + Center) * 0.33333333;
	float4 blurredV   = ( combV + Center) * 0.33333333;
	
	float LumH        = LI( blurredH.rgb );
	float LumV        = LI( blurredV.rgb );
		
	float satAmountH = saturate( ( lambda * EdgeLumH - epsilon ) / LumH );
    float satAmountV = saturate( ( lambda * EdgeLumV - epsilon ) / LumV );
	
	//Re-blend
	Done = lerp( Center,  blurredH, satAmountH );
	Done = lerp( Center,  blurredV, satAmountV );
	
	if(Debug_View)
	{
		Done = EdgeLumH.xxxx;
	}
	else
	{
		Done = Done;
	}
	
	return Done;
}

float4 LongEdge(float2 texcoord)
{
	float4 Center, HNegA, HNegB, HNegC, HNegD, HPosA, HPosB, HPosC, HPosD, VNegA, VNegB, VNegC, VNegD, VPosA, VPosB, VPosC, VPosD,DLAA_Out;
	//Reuse shot samples
	float4 SEdge = shortEdge(texcoord);
		
	// Long Edges
	Center = tex2D(BackBuffer, texcoord);
    
    //16 bi-linear samples cross
	HNegA   = tex2D(BackBuffer, texcoord + float2(-1.5 * pix.x,  0.0) );
	HNegB   = tex2D(BackBuffer, texcoord + float2(-3.5 * pix.x,  0.0) );
	HNegC   = tex2D(BackBuffer, texcoord + float2(-5.5 * pix.x,  0.0) );
	HNegD   = tex2D(BackBuffer, texcoord + float2(-7.5 * pix.x,  0.0) );
	HPosA   = tex2D(BackBuffer, texcoord + float2( 1.5 * pix.x,  0.0) );
	HPosB   = tex2D(BackBuffer, texcoord + float2( 3.5 * pix.x,  0.0) );
	HPosC   = tex2D(BackBuffer, texcoord + float2( 5.5 * pix.x,  0.0) );
	HPosD   = tex2D(BackBuffer, texcoord + float2( 7.5 * pix.x,  0.0) );
	 
	VNegA   = tex2D(BackBuffer, texcoord + float2( 0.0,-1.5 * pix.y) );
	VNegB   = tex2D(BackBuffer, texcoord + float2( 0.0,-3.5 * pix.y) );
	VNegC   = tex2D(BackBuffer, texcoord + float2( 0.0,-5.5 * pix.y) );
	VNegD   = tex2D(BackBuffer, texcoord + float2( 0.0,-7.5 * pix.y) );
	VPosA   = tex2D(BackBuffer, texcoord + float2( 0.0, 1.5 * pix.y) );
	VPosB   = tex2D(BackBuffer, texcoord + float2( 0.0, 3.5 * pix.y) );
	VPosC   = tex2D(BackBuffer, texcoord + float2( 0.0, 5.5 * pix.y) );
	VPosD   = tex2D(BackBuffer, texcoord + float2( 0.0, 7.5 * pix.y) );
	
	float longEdgeH = ( HNegA.a + HNegB.a + HNegC.a + HNegD.a + HPosA.a + HPosB.a + HPosC.a + HPosD.a ) * 0.125;
    float longEdgeV = ( VNegA.a + VNegB.a + VNegC.a + VNegD.a + VPosA.a + VPosB.a + VPosC.a + VPosD.a ) * 0.125;
 
    longEdgeH = saturate( longEdgeH * 2.0 - 1.0 );
    longEdgeV = saturate( longEdgeV * 2.0 - 1.0 );
    
    //float longEdge = max( longEdgeH , longEdgeV);   
    //if ( longEdge > 1.0 )
    //if ( longEdgeH > 0 || longEdgeV > 0 )
    //Ended useing This instead of the other 2 above
    //This was taken from https://github.uconn.edu/eec09006/breakout/blob/master/breakout/Assets/Standard%20Assets/Effects/ImageEffects/Shaders/_Antialiasing/DLAA.shader#L135
    //Thank you
    if ( abs( longEdgeH - longEdgeV ) > 0.2 )
	{
    float4 CenterH = Center, CenterV = Center; 
    float4 longEdgeBlurH= ( HNegA + HNegB + HNegC + HNegD + HPosA + HPosB + HPosC + HPosD ) * 0.125;
    float4 longEdgeBlurV= ( VNegA + VNegB + VNegC + VNegD + VPosA + VPosB + VPosC + VPosD ) * 0.125;
    
    float LongBlurLumH	= LI( longEdgeBlurH.rgb );
	float LongBlurLumV	= LI( longEdgeBlurV.rgb );
	
	float4 Left			= tex2D(BackBuffer, texcoord + float2(-pix.x,  0.0) );
	float4 Right		= tex2D(BackBuffer, texcoord + float2( pix.x,  0.0) );
	float4 Up			= tex2D(BackBuffer, texcoord + float2( 0.0, -pix.y) );
	float4 Down			= tex2D(BackBuffer, texcoord + float2( 0.0,  pix.y) );    
	
	float CenterLI		= LI( Center.rgb );
	float LeftLI		= LI( Left.rgb );
	float RightLI		= LI( Right.rgb );
	float UpLI			= LI( Up.rgb );
	float DownLI		= LI( Down.rgb );
			
	float4 CenterDiff	= CenterLI - float4(LeftLI, UpLI, RightLI, DownLI);      
	float blurLeft 		= saturate( 0.0 + ( LongBlurLumV - LeftLI   ) / CenterDiff.x );
	float blurUp   		= saturate( 0.0 + ( LongBlurLumH - UpLI     ) / CenterDiff.y );
	float blurRight		= saturate( 1.0 + ( LongBlurLumV - CenterLI ) / CenterDiff.z );
	float blurDown 		= saturate( 1.0 + ( LongBlurLumH - CenterLI ) / CenterDiff.w );     

	float4 Cross   		= float4( blurLeft, blurRight, blurUp, blurDown );
		   Cross  		= ( Cross == float4(0.0, 0.0, 0.0, 0.0) ) ? float4(1.0, 1.0, 1.0, 1.0) : Cross;

	CenterH				= lerp( Left, CenterH,  Cross.x );
	CenterH				= lerp( Right,CenterH, Cross.y );
	CenterV 			= lerp( Up,   CenterV,  Cross.z );
	CenterV 			= lerp( Down, CenterV, Cross.w );
    	
    SEdge = lerp( SEdge, CenterH, LongBlurLumH);
	SEdge = lerp( SEdge, CenterV, LongBlurLumV);  
    }
    
    DLAA_Out = SEdge;
    
	return DLAA_Out;
}

float4 DLAA(float2 texcoord : TEXCOORD0)
{		
	float4 Out;

		if(Debug_View)
	{
		Out = float4(shortEdge(texcoord).rgb,1.0);
	}
	else
	{
		Out = float4(LongEdge(texcoord).rgb,1.0);
	}		
	
	return Out;
}

////////////////////////////////////////////////////////Logo/////////////////////////////////////////////////////////////////////////
uniform float timer < source = "timer"; >;
float4 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float PosX = 0.5*BUFFER_WIDTH*pix.x,PosY = 0.5*BUFFER_HEIGHT*pix.y;	
	float4 Color = DLAA(texcoord),Done,Website,D,E,P,T,H,Three,DD,Dot,I,N,F,O;
	
	if(timer <= 10000)
	{
	//DEPTH
	//D
	float PosXD = -0.035+PosX, offsetD = 0.001;
	float4 OneD = all( abs(float2( texcoord.x -PosXD, texcoord.y-PosY)) < float2(0.0025,0.009));
	float4 TwoD = all( abs(float2( texcoord.x -PosXD-offsetD, texcoord.y-PosY)) < float2(0.0025,0.007));
	D = OneD-TwoD;
	
	//E
	float PosXE = -0.028+PosX, offsetE = 0.0005;
	float4 OneE = all( abs(float2( texcoord.x -PosXE, texcoord.y-PosY)) < float2(0.003,0.009));
	float4 TwoE = all( abs(float2( texcoord.x -PosXE-offsetE, texcoord.y-PosY)) < float2(0.0025,0.007));
	float4 ThreeE = all( abs(float2( texcoord.x -PosXE, texcoord.y-PosY)) < float2(0.003,0.001));
	E = (OneE-TwoE)+ThreeE;
	
	//P
	float PosXP = -0.0215+PosX, PosYP = -0.0025+PosY, offsetP = 0.001, offsetP1 = 0.002;
	float4 OneP = all( abs(float2( texcoord.x -PosXP, texcoord.y-PosYP)) < float2(0.0025,0.009*0.682));
	float4 TwoP = all( abs(float2( texcoord.x -PosXP-offsetP, texcoord.y-PosYP)) < float2(0.0025,0.007*0.682));
	float4 ThreeP = all( abs(float2( texcoord.x -PosXP+offsetP1, texcoord.y-PosY)) < float2(0.0005,0.009));
	P = (OneP-TwoP) + ThreeP;

	//T
	float PosXT = -0.014+PosX, PosYT = -0.008+PosY;
	float4 OneT = all( abs(float2( texcoord.x -PosXT, texcoord.y-PosYT)) < float2(0.003,0.001));
	float4 TwoT = all( abs(float2( texcoord.x -PosXT, texcoord.y-PosY)) < float2(0.000625,0.009));
	T = OneT+TwoT;
	
	//H
	float PosXH = -0.0071+PosX;
	float4 OneH = all( abs(float2( texcoord.x -PosXH, texcoord.y-PosY)) < float2(0.002,0.001));
	float4 TwoH = all( abs(float2( texcoord.x -PosXH, texcoord.y-PosY)) < float2(0.002,0.009));
	float4 ThreeH = all( abs(float2( texcoord.x -PosXH, texcoord.y-PosY)) < float2(0.003,0.009));
	H = (OneH-TwoH)+ThreeH;
	
	//Three
	float offsetFive = 0.001, PosX3 = -0.001+PosX;
	float4 OneThree = all( abs(float2( texcoord.x -PosX3, texcoord.y-PosY)) < float2(0.002,0.009));
	float4 TwoThree = all( abs(float2( texcoord.x -PosX3 - offsetFive, texcoord.y-PosY)) < float2(0.003,0.007));
	float4 ThreeThree = all( abs(float2( texcoord.x -PosX3, texcoord.y-PosY)) < float2(0.002,0.001));
	Three = (OneThree-TwoThree)+ThreeThree;
	
	//DD
	float PosXDD = 0.006+PosX, offsetDD = 0.001;	
	float4 OneDD = all( abs(float2( texcoord.x -PosXDD, texcoord.y-PosY)) < float2(0.0025,0.009));
	float4 TwoDD = all( abs(float2( texcoord.x -PosXDD-offsetDD, texcoord.y-PosY)) < float2(0.0025,0.007));
	DD = OneDD-TwoDD;
	
	//Dot
	float PosXDot = 0.011+PosX, PosYDot = 0.008+PosY;		
	float4 OneDot = all( abs(float2( texcoord.x -PosXDot, texcoord.y-PosYDot)) < float2(0.00075,0.0015));
	Dot = OneDot;
	
	//INFO
	//I
	float PosXI = 0.0155+PosX, PosYI = 0.004+PosY, PosYII = 0.008+PosY;
	float4 OneI = all( abs(float2( texcoord.x - PosXI, texcoord.y - PosY)) < float2(0.003,0.001));
	float4 TwoI = all( abs(float2( texcoord.x - PosXI, texcoord.y - PosYI)) < float2(0.000625,0.005));
	float4 ThreeI = all( abs(float2( texcoord.x - PosXI, texcoord.y - PosYII)) < float2(0.003,0.001));
	I = OneI+TwoI+ThreeI;
	
	//N
	float PosXN = 0.0225+PosX, PosYN = 0.005+PosY,offsetN = -0.001;
	float4 OneN = all( abs(float2( texcoord.x - PosXN, texcoord.y - PosYN)) < float2(0.002,0.004));
	float4 TwoN = all( abs(float2( texcoord.x - PosXN, texcoord.y - PosYN - offsetN)) < float2(0.003,0.005));
	N = OneN-TwoN;
	
	//F
	float PosXF = 0.029+PosX, PosYF = 0.004+PosY, offsetF = 0.0005, offsetF1 = 0.001;
	float4 OneF = all( abs(float2( texcoord.x -PosXF-offsetF, texcoord.y-PosYF-offsetF1)) < float2(0.002,0.004));
	float4 TwoF = all( abs(float2( texcoord.x -PosXF, texcoord.y-PosYF)) < float2(0.0025,0.005));
	float4 ThreeF = all( abs(float2( texcoord.x -PosXF, texcoord.y-PosYF)) < float2(0.0015,0.00075));
	F = (OneF-TwoF)+ThreeF;
	
	//O
	float PosXO = 0.035+PosX, PosYO = 0.004+PosY;
	float4 OneO = all( abs(float2( texcoord.x -PosXO, texcoord.y-PosYO)) < float2(0.003,0.005));
	float4 TwoO = all( abs(float2( texcoord.x -PosXO, texcoord.y-PosYO)) < float2(0.002,0.003));
	O = OneO-TwoO;
	}
	
	Website = D+E+P+T+H+Three+DD+Dot+I+N+F+O ? float4(1.0,1.0,1.0,1) : Color;
	
	if(timer >= 10000)
	{
	Done = Color;
	}
	else
	{
	Done = Website;
	}

	return Done;
}

///////////////////////////////////////////////////////////ReShade.fxh/////////////////////////////////////////////////////////////

// Vertex shader generating a triangle covering the entire screen
void PostProcessVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

//*Rendering passes*//
technique Directionally_Localized_Anti_Aliasing
{
			pass DLAA
		{
			VertexShader = PostProcessVS;
			PixelShader = Out;	
		}
}