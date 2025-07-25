#!/usr/bin/python3

import subprocess
import json
import sys

def get_dunst_history():
   
    return None

def format_history(history):
    count = len(history['data'][0])
    alt = 'none'
    tooltip_click = []
    tooltip_click.append("󰎟 Notifications")
    tooltip_click.append("󰳽 scroll-down:  history pop")
    tooltip_click.append("󰳽 click-left:  Enable & Disable DND")
    tooltip_click.append("󰳽 click-middle: 󰛌 clear history")
    tooltip_click.append("󰳽 click-right: 󱄊 close all")

    tooltip = []

    if count > 0:
        notifications = history['data'][0][:10]  # Get the first 10 notifications
        for notification in notifications:
            body = notification.get('body', {}).get('data', '')
            category = notification.get('category', {}).get('data', '')
            if category:
                alt = category + '-notification'
                tooltip.append(f" {body} ({category})\n")
            else:
                alt = 'notification'
                tooltip.append(f" {body}\n")

    isDND = "1"
    if isDND != '0':
        alt = "dnd"
    formatted_history = {
        "text": str(count),
        "alt": alt,
        "tooltip": '\n '.join(tooltip_click) + '\n\n ' + '\n '.join(tooltip),
        "class": alt
    }
    return formatted_history

def main():
   pass

if __name__ == "__main__":
    main()
