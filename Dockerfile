##############################################################################
# Stage 1: Export all Godot demo projects to HTML5/Web
##############################################################################
FROM barichello/godot-ci:4.5.1 AS builder

ENV GODOT_VERSION=4.5.1

WORKDIR /app

# Copy the full project into the container
COPY . .

# Set up Godot export templates
RUN mkdir -p ~/.local/share/godot/export_templates/ \
    && mv /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable \
       ~/.local/share/godot/export_templates/${GODOT_VERSION}.stable

# Install imagemagick for panorama resizing
RUN apt-get update -qq && apt-get install -qqq imagemagick

# Remove demos that cannot be exported to Web
RUN rm -rf \
    2d/glow/ \
    2d/navigation_mesh_chunks/ \
    2d/physics_tests/ \
    3d/labels_and_texts/ \
    3d/decals/ \
    3d/ik/ \
    3d/navigation_mesh_chunks/ \
    3d/occlusion_culling_mesh_lod/ \
    3d/particles/ \
    3d/physical_light_camera_units/ \
    3d/physics_tests/ \
    3d/variable_rate_shading/ \
    3d/volumetric_fog/ \
    3d/voxel/ \
    audio/bpm_sync/ \
    audio/device_changer/ \
    audio/midi_piano/ \
    audio/spectrum/ \
    compute/ \
    gui/msdf_font/ \
    gui/translation/ \
    loading/runtime_save_load \
    misc/compute_shader_heightmap \
    misc/large_world_coordinates/ \
    misc/matrix_transform/ \
    mobile/android_iap/ \
    mobile/sensors/ \
    mono/ \
    networking/ \
    plugins/ \
    xr/openxr_character_centric_movement \
    xr/openxr_composition_layers \
    xr/openxr_hand_tracking_demo \
    xr/openxr_origin_centric_movement

# Resize HDR panoramas to stay below PCK size limits
RUN for panorama in 3d/material_testers/backgrounds/*.hdr; do \
        [ -f "$panorama" ] && mogrify -resize 66.667% "$panorama"; \
    done

# Export each demo project to Web (HTML5)
RUN BASEDIR="$PWD" && \
    for demo in */*/; do \
        echo "==== Exporting $demo ====" && \
        mkdir -p "$BASEDIR/.github/dist/$demo" && \
        cd "$BASEDIR/$demo" && \
        cp "$BASEDIR/.github/dist/export_presets.cfg" . && \
        printf '[rendering]\n\ntextures/vram_compression/import_etc2_astc=true' >> project.godot && \
        godot --verbose --headless --export-release "Web" "$BASEDIR/.github/dist/$demo/index.html" && \
        mv -f "$BASEDIR/.github/dist/$demo/index.wasm" "$BASEDIR/.github/dist/index.wasm" && \
        ln -sf "../../index.wasm" "$BASEDIR/.github/dist/$demo/index.wasm" && \
        PROJECT_NAME=$(grep "config/name" project.godot | cut -d '"' -f 2 | tr -d "\n") && \
        echo "<li><a href='$demo'><img width=\"64\" height=\"64\" src=\"$demo/index.icon.png\" alt=\"\"><p>$PROJECT_NAME</p></a></li>" >> "$BASEDIR/.github/dist/demos.html"; \
        cd "$BASEDIR"; \
    done && \
    cat "$BASEDIR/.github/dist/header.html" "$BASEDIR/.github/dist/demos.html" "$BASEDIR/.github/dist/footer.html" > "$BASEDIR/.github/dist/index.html" && \
    rm -f "$BASEDIR/.github/dist/header.html" "$BASEDIR/.github/dist/demos.html" "$BASEDIR/.github/dist/footer.html" "$BASEDIR/.github/dist/export_presets.cfg"

##############################################################################
# Stage 2: Serve the exported demos with a lightweight web server
##############################################################################
FROM nginx:alpine

# Required headers for SharedArrayBuffer support (needed by Godot Web exports)
RUN echo 'server { \
    listen 10000; \
    server_name _; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ =404; \
        add_header Cross-Origin-Opener-Policy "same-origin" always; \
        add_header Cross-Origin-Embedder-Policy "require-corp" always; \
    } \
    # Correct MIME types for Godot Web exports \
    types { \
        application/wasm wasm; \
        application/javascript js; \
        application/octet-stream pck; \
    } \
}' > /etc/nginx/conf.d/default.conf

COPY --from=builder /app/.github/dist/ /usr/share/nginx/html/

EXPOSE 10000

CMD ["nginx", "-g", "daemon off;"]
