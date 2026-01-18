"""
Jellyfin/Plex Media Renamer

A smart, cross-platform tool that renames TV show files for media server compatibility.
"""

from importlib.metadata import version, PackageNotFoundError

try:
    __version__ = version("jellyfin-renamer")
except PackageNotFoundError:
    # Running from source without installation
    __version__ = "0.0.0-dev"
