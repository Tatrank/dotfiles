#!/usr/bin/env python3
# filepath: g:\dotfiles\HyDE\Configs\.local\lib\hyde\matugen_to_dcol.py

import argparse
import json
import subprocess
import sys
import colorsys
import re
from pathlib import Path

def hex_to_rgba(hex_color):
    """Convert hex color to rgba string format"""
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return f"rgba({r},{g},{b},\1341)"

def is_dark(hex_color):
    """Determine if a color is dark (for text contrast)"""
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0
    luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return luminance < 0.5

def generate_accent_colors(hex_color, curve_points, is_light_mode=False):
    """Generate accent colors based on HSV adjustments"""
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0
    
    # Convert to HSV
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    
    accent_colors = []
    
    # Sort curve points based on mode
    curve_points = sorted(curve_points, reverse=is_light_mode)
    
    for brightness, saturation in curve_points:
        # Adjust brightness and saturation (normalized to 0-1)
        new_s = saturation / 100.0
        new_v = brightness / 100.0
        
        # Convert back to RGB
        r, g, b = colorsys.hsv_to_rgb(h, new_s, new_v)
        
        # Convert to hex
        hex_value = f"{int(r*255):02X}{int(g*255):02X}{int(b*255):02X}"
        accent_colors.append(hex_value)
    
    return accent_colors

def generate_text_color(hex_color):
    """Generate a contrasting text color"""
    hex_color = hex_color.lstrip('#')
    
    # Calculate negative/inverse color
    r = 255 - int(hex_color[0:2], 16)
    g = 255 - int(hex_color[2:4], 16)
    b = 255 - int(hex_color[4:6], 16)
    
    # Adjust brightness based on original color darkness
    if is_dark(f"#{hex_color}"):
        brightness_mod = 1.88  # txtDarkBri equivalent (188%)
    else:
        brightness_mod = 0.16  # txtLightBri equivalent (16%)
    
    # Convert to HSV for brightness adjustment
    h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
    
    # Apply brightness mod and reduce saturation
    v = min(1.0, v * brightness_mod)
    s = 0.1  # Low saturation for better contrast
    
    # Convert back to RGB
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    
    # Return hex
    return f"{int(r*255):02X}{int(g*255):02X}{int(b*255):02X}"

def parse_curve(curve_str):
    """Parse color curve string into tuples of (brightness, saturation)"""
    curve_points = []
    for line in curve_str.strip().split('\\n'):
        brightness, saturation = map(int, line.strip().split())
        curve_points.append((brightness, saturation))
    return curve_points

def main():
    parser = argparse.ArgumentParser(description="Generate dcol files using matugen")
    parser.add_argument("image", help="Path to the image")
    parser.add_argument("--palette", choices=["vibrant", "pastel", "neutral"], 
                        default="default", help="Color palette style")
    parser.add_argument("--mode", choices=["dark", "light", "auto"], 
                        default="auto", help="Color mode")
    
    # Parse arguments
    args = parser.parse_args()
    image_path = args.image
    palette_style = args.palette
    color_mode = args.mode
    
    # Define color curves for different profiles
    curves = {
        "default": "32 50\n42 46\n49 40\n56 39\n64 38\n76 37\n90 33\n94 29\n100 20",
        "vibrant": "18 99\n32 97\n48 95\n55 90\n70 80\n80 70\n88 60\n94 40\n99 24",
        "pastel": "10 99\n17 66\n24 49\n39 41\n51 37\n58 34\n72 30\n84 26\n99 22",
        "neutral": "10 0\n17 0\n24 0\n39 0\n51 0\n58 0\n72 0\n84 0\n99 0"
    }
    
    # Choose the curve based on palette style
    wallbash_curve = parse_curve(curves.get(palette_style, curves["default"]))
    
    # Run matugen to get colors
    try:
        cmd = ["matugen", "image", "-o", "json", image_path]
        if color_mode != "auto":
            cmd.extend(["--mode", color_mode])
        
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        colors_json = json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error running matugen: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print("Error parsing matugen output", file=sys.stderr)
        sys.exit(1)
    
    # Determine mode (dark or light)
    if color_mode == "auto":
        # Get background color and determine if it's dark
        bg_color = colors_json["colors"]["background"]["default"]["hex"].lstrip('#')
        is_light_mode = not is_dark(f"#{bg_color}")
        mode = "light" if is_light_mode else "dark"
    else:
        mode = color_mode
        is_light_mode = (mode == "light")
    
    # Extract 4 primary colors
    primary_colors = []
    
    # Get colors in priority order from the matugen output
    color_keys = ["primary", "secondary", "tertiary", "error"]
    
    # Add additional colors if needed
    additional_colors = ["background", "surface_bright", "surface", "outline"]
    
    # Combine all possible colors
    all_color_keys = color_keys + additional_colors
    
    # Get unique colors until we have 4
    for key in all_color_keys:
        if key in colors_json["colors"] and len(primary_colors) < 4:
            hex_color = colors_json["colors"][key]["default"]["hex"].lstrip('#')
            if hex_color not in primary_colors:
                primary_colors.append(hex_color)
    
    # Ensure we have 4 colors (duplicate the last one if needed)
    while len(primary_colors) < 4:
        primary_colors.append(primary_colors[-1])
    
    # Generate output file
    output_path = f"{image_path}.dcol"
    with open(output_path, "w") as f:
        # Write mode
        f.write(f"dcol_mode=\"{mode}\"\n")
        
        # Process each primary color
        for i, color in enumerate(primary_colors, 1):
            # Write primary color
            f.write(f"dcol_pry{i}=\"{color}\"\n")
            f.write(f"dcol_pry{i}_rgba=\"{hex_to_rgba(color)}\"\n")
            
            # Generate text color
            text_color = generate_text_color(color)
            f.write(f"dcol_txt{i}=\"{text_color}\"\n")
            f.write(f"dcol_txt{i}_rgba=\"{hex_to_rgba(text_color)}\"\n")
            
            # Generate accent colors
            accent_colors = generate_accent_colors(color, wallbash_curve, is_light_mode)
            for j, accent in enumerate(accent_colors, 1):
                f.write(f"dcol_{i}xa{j}=\"{accent}\"\n")
                f.write(f"dcol_{i}xa{j}_rgba=\"{hex_to_rgba(accent)}\"\n")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

