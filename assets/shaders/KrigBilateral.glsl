//!HOOK LINEAR
//!BIND HOOKED
//!BIND LUMA
//!SAVE HOOKED
//!WIDTH LUMA.width
//!HEIGHT LUMA.height
//!WHEN CHROMA.width LUMA.width <
//!DESC KrigBilateral (Chroma Upscaling)

// KrigBilateral by Shiandow

#define KERNEL ewa_lanczos

vec4 hook() {
    vec2 pos = HOOKED_pos;
    vec2 size = HOOKED_size;
    
    vec4 chroma = HOOKED_tex(pos);
    float luma = LUMA_tex(pos).x;
    
    float total_weight = 1.0;
    vec4 total_chroma = chroma;
    
    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            if(x == 0 && y == 0) continue;
            vec2 offset = vec2(x, y) / size;
            float luma_sample = LUMA_tex(pos + offset).x;
            float weight = 1.0 / (1.0 + 200.0 * pow(luma - luma_sample, 2.0));
            total_chroma += weight * HOOKED_tex(pos + offset);
            total_weight += weight;
        }
    }
    return total_chroma / total_weight;
}
