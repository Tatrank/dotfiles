import json
import subprocess
import sys
import os

def hex_to_rgba(hex_color, alpha=0.95):
    """Converts a hex color string to an rgba string."""
    hex_color = hex_color.lstrip('#')
    r, g, b = tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))
    return f"rgba({r},{g},{b},{alpha})"

def generate_dcol(image_path):
    """
    Generates dcol color scheme from an image using matugen and maps it
    to the legacy dcol variable format.
    """
    if not os.path.exists(image_path):
        print(f"Error: Image path does not exist: {image_path}", file=sys.stderr)
        sys.exit(1)

    try:
        # Get color palette from matugen as JSON
        result = subprocess.run(
            ['matugen', '-j', 'image', image_path],
            capture_output=True,
            text=True,
            check=True
        )
        colors = json.loads(result.stdout)
    except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error running matugen or parsing its output: {e}", file=sys.stderr)
        sys.exit(1)

    # --- Mapping Matugen colors to the dcol scheme ---
    # We map the main Material You roles to the 4 primary dcol groups.
    dcol_map = {
        'pry1': colors['colors']['primary'],
        'txt1': colors['colors']['on_primary'],
        'pry2': colors['colors']['secondary'],
        'txt2': colors['colors']['on_secondary'],
        'pry3': colors['colors']['tertiary'],
        'txt3': colors['colors']['on_tertiary'],
        'pry4': colors['colors']['surface_bright'], # Using surface_bright as the 4th primary
        'txt4': colors['colors']['on_surface'],
    }

    # Map the 9 accent colors for each primary group to the tonal palettes from matugen
    tonal_map = {
        '1': colors['palettes']['primary'],
        '2': colors['palettes']['secondary'],
        '3': colors['palettes']['tertiary'],
        '4': colors['palettes']['neutral'], # Using neutral palette for surface accents
    }
    
    accent_indices = ['10', '20', '30', '40', '50', '60', '70', '80', '90']

    # --- Generate the output in .dcol format ---
    output = []
    
    # Determine dark/light mode from matugen
    mode = 'dark' if colors['dark'] else 'light'
    output.append(f'dcol_mode="{mode}"')

    for i in range(1, 5):
        # Primary and Text colors
        pry_hex = dcol_map[f'pry{i}'].lstrip('#')
        txt_hex = dcol_map[f'txt{i}'].lstrip('#')
        output.append(f'dcol_pry{i}="{pry_hex}"')
        output.append(f'dcol_pry{i}_rgba="{hex_to_rgba(pry_hex)}"')
        output.append(f'dcol_txt{i}="{txt_hex}"')
        output.append(f'dcol_txt{i}_rgba="{hex_to_rgba(txt_hex)}"')

        # Accent colors from tonal palettes
        palette = tonal_map[str(i)]
        for j, accent_index in enumerate(accent_indices, 1):
            accent_hex = palette[accent_index].lstrip('#')
            output.append(f'dcol_{i}xa{j}="{accent_hex}"')
            output.append(f'dcol_{i}xa{j}_rgba="{hex_to_rgba(accent_hex)}"')

    print('\n'.join(output))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python matugen_to_dcol.py <path_to_image>", file=sys.stderr)
        sys.exit(1)
    generate_dcol(sys.argv[1])
