#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// First pass: extract bright highlights and downsample 2x to mip0
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D source_img;
layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D dest_img;

layout(push_constant, std430) uniform PushConstant {
    float threshold;
    float knee;
    float pad0; float pad1;
    float pad2; float pad3; float pad4; float pad5; // D3D12 32-byte alignment
} pc;

void main() {
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dest_size = imageSize(dest_img);
    if (coord.x >= dest_size.x || coord.y >= dest_size.y) return;
    
    // Read 2x2 box from high res buffer natively without bilinear interpolation
    ivec2 src_coord = coord * 2;
    ivec2 src_size = imageSize(source_img);
    
    // Nearest neighbor gather for the exact 4 pixels forming the box
    vec3 c00 = imageLoad(source_img, clamp(src_coord, ivec2(0), src_size - 1)).rgb;
    vec3 c10 = imageLoad(source_img, clamp(src_coord + ivec2(1,0), ivec2(0), src_size - 1)).rgb;
    vec3 c01 = imageLoad(source_img, clamp(src_coord + ivec2(0,1), ivec2(0), src_size - 1)).rgb;
    vec3 c11 = imageLoad(source_img, clamp(src_coord + ivec2(1,1), ivec2(0), src_size - 1)).rgb;
    
    vec3 avg = (c00 + c10 + c01 + c11) * 0.25;
    
    // Soft-knee Thresholding logic (extracts blooms without harsh clipping)
    float luma = max(avg.r, max(avg.g, avg.b));
    float rq = clamp(luma - pc.threshold + pc.knee, 0.0, pc.knee * 2.0);
    float val = max(luma - pc.threshold, (rq * rq) / (4.0 * pc.knee + 0.0001));
    avg = avg * (val / max(luma, 0.0001));
    
    imageStore(dest_img, coord, vec4(avg, 1.0));
}
