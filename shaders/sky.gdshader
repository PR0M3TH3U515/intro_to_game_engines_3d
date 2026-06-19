shader_type sky;

// The base texture slots with correct color and filter hints
uniform sampler2D skyTexture : source_color, filter_linear_mipmap;
uniform sampler2D evolutionNoise : filter_linear_mipmap; 

// Tint controls: Choose a color and how much it affects the sky
uniform vec4 skyTint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tintAmount : hint_range(0.0, 1.0) = 0.5;

// Contrast control: Higher numbers make lights brighter and darks darker
uniform float contrast : hint_range(0.0, 3.0) = 1.0;

// Exposure control: Multiplies the overall brightness of the sky
uniform float exposure : hint_range(0.0, 5.0) = 1.0;

// Warp controls: Dictates how fast and how hard the clouds wiggle out of shape
uniform float warpSpeed : hint_range(0.0, 2.0) = 0.2;
uniform float warpStrength : hint_range(0.0, 0.1) = 0.015;

// Dissolve controls: Dictates how fast and deeply the clouds fade in and out
uniform float dissolveSpeed : hint_range(0.0, 2.0) = 0.05;
uniform float dissolveStrength : hint_range(0.0, 1.0) = 0.3;

void sky() {
    // 1. Establish clean, native background coordinates
    vec2 baseCoords = SKY_COORDS;
    
    // 2. Lock pixel changes before editing coordinates
    // This stops the GPU from creating pixel artifacts at the wrap-around seams
    vec2 dx = dFdx(baseCoords);
    vec2 dy = dFdy(baseCoords);
    
    // 3. Create a cloud mask based on the image's brightness
    // This ensures our animations only touch the clouds and not the blue sky
    vec3 checkColor = textureGrad(skyTexture, baseCoords, dx, dy).rgb;
    float cloudMask = max(checkColor.r, max(checkColor.g, checkColor.b));
    cloudMask = smoothstep(0.4, 0.8, cloudMask);
    
    // 4. Calculate the warp distortion waves using TIME
    float warpTime = TIME * warpSpeed;
    float warpX = sin(baseCoords.y * 12.0 + warpTime) * warpStrength;
    float warpY = cos(baseCoords.x * 12.0 + warpTime) * warpStrength;
    
    // 5. Apply the warp coordinates strictly where the clouds are
    vec2 distortedCoords = baseCoords;
    distortedCoords.x += warpX * cloudMask;
    distortedCoords.y += warpY * cloudMask;
    
    // 6. Sample the main HDRI image using our new warped coordinates
    vec3 originalColor = textureGrad(skyTexture, distortedCoords, dx, dy).rgb;
    
    // 7. Calculate the noise evolution coordinates over TIME to simulate wind
    vec2 noiseCoords = baseCoords + vec2(TIME * dissolveSpeed * 0.1, TIME * dissolveSpeed * 0.05);
    vec3 noiseValue = textureGrad(evolutionNoise, noiseCoords, dx, dy).rgb;
    
    // 8. Use the noise values to blend clouds in and out of existence
    float dissolveFactor = (noiseValue.r - 0.5) * dissolveStrength * cloudMask;
    originalColor = clamp(originalColor + vec3(dissolveFactor), 0.0, 3.0);
    
    // 9. Core image controls: Apply the tint color blend
    vec3 tintedColor = originalColor * skyTint.rgb;
    vec3 finalColor = mix(originalColor, tintedColor, tintAmount);
    
    // 10. Core image controls: Apply the contrast adjustment
    finalColor = mix(vec3(0.5), finalColor, contrast);
    
    // 11. Core image controls: Apply the final exposure multiplier
    finalColor = finalColor * exposure;
    
    // 12. Output the fully animated and color-adjusted pixel to the sky
    COLOR = finalColor;
}
