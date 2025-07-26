#!/bin/bash

# Build the app
echo "Building File Organizer App..."
swift build -c release

# Run the app
echo "Launching File Organizer App..."
.build/release/FileOrganizerApp 