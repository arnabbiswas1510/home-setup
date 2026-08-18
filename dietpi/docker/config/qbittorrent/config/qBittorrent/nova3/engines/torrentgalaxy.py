# VERSION: 1.2
# AUTHORS: LightDestory (https://github.com/LightDestory)

import re
import urllib.parse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from helpers import download_file, retrieve_url
from novaprinter import prettyPrinter
from time import sleep


class torrentgalaxy(object):
    url = "https://torrentgalaxy.one/"
    name = "TorrentGalaxy"
    supported_categories = {
        "all": "",
        "movies": "Movies",
        "tv": "TV",
        "music": "Music",
        "games": "Games",
        "anime": "Anime",
        "software": "Apps",
        "books": "Books",
    }

    class HTMLParser:
        def __init__(self, url):
            self.url = url
            self.noTorrents = False

        def feed(self, html):
            self.noTorrents = False
            torrents = self.__findTorrents(html)
            if len(torrents) == 0:
                self.noTorrents = True
                return
            for data in torrents:
                prettyPrinter(data)

        def _process_row(self, tr):
            post_match = re.search(
                r"<a [^>]*href=[\"\x27](/post-detail/[^\x27\"]+)[\"\x27][^>]*>(?:<span[^>]*>)?<b>(.*?)</b>",
                tr,
            )
            if not post_match:
                post_match = re.search(
                    r"<a [^>]*href=[\"\x27](/post-detail/[^\x27\"]+)[\"\x27][^>]*title=[\"\x27]([^\x27\"]+)[\"\x27]",
                    tr,
                )
            size_match = re.search(
                r"([0-9\,\.]+\s*(?:TB|GB|MB|KB|B|bytes))",
                tr,
            )
            seeds_leech = re.search(
                r"\[<font color=[\"\x27]green[\"\x27]><b>([0-9,]+)</b></font>/<font color=[\"\x27]#ff0000[\"\x27]><b>([0-9,]+)</b>",
                tr,
            )
            if not (post_match and size_match and seeds_leech):
                return None

            detail_path = post_match.group(1)
            title = post_match.group(2)
            size = size_match.group(1)
            seeds = int(seeds_leech.group(1).replace(",", ""))
            leech = int(seeds_leech.group(2).replace(",", ""))
            base_url = self.url.rstrip("/")
            desc_url = f"{base_url}{detail_path}"

            # Fetch the post detail page to extract the direct magnet link
            mag_link = desc_url
            try:
                detail_html = retrieve_url(desc_url)
                mag_match = re.search(r"href=[\"\x27](magnet:\?[^\x27\"]+)[\"\x27]", detail_html)
                if mag_match:
                    mag_link = mag_match.group(1)
            except Exception:
                pass

            return {
                "link": mag_link,
                "name": title,
                "size": size,
                "seeds": seeds,
                "leech": leech,
                "engine_url": self.url,
                "desc_link": desc_url,
                "pub_date": -1,
            }

        def __findTorrents(self, html):
            trs = re.findall(
                r"<div class=\"tgxtablerow txlight\".+?</table>\s?</div>", html
            )
            if not trs:
                return []

            with ThreadPoolExecutor(max_workers=20) as executor:
                results = list(executor.map(self._process_row, trs))

            return [r for r in results if r is not None]

    def download_torrent(self, info):
        if info.startswith("magnet:"):
            print(f"{info} {info}")
            return

        torrent_page = retrieve_url(info)
        if not torrent_page:
            raise Exception("Failed to retrieve torrent page")

        if "/post-detail/" not in info:
            post_match = re.search(r"href=[\"\x27](/post-detail/[^\x27\"]+)[\"\x27]", torrent_page)
            if post_match:
                base_url = self.url.rstrip("/")
                detail_url = f"{base_url}{post_match.group(1)}"
                torrent_page = retrieve_url(detail_url)

        # Try downloading .torrent file from itorrents
        itorrents_match = re.search(r"href=[\"\x27](https?://itorrents\.[^\x27\"]+)[\"\x27]", torrent_page)
        if itorrents_match:
            try:
                res = download_file(itorrents_match.group(1))
                print(res)
                return
            except Exception:
                pass

        # Fallback to magnet link
        magnet_match = re.search(r"href=[\"\x27](magnet:\?[^\x27\"]+)[\"\x27]", torrent_page)
        if magnet_match:
            mag = magnet_match.group(1)
            print(f"{mag} {mag}")
            return

        raise Exception("Download link not found")

    def search(self, what, cat="all"):
        what = urllib.parse.quote(urllib.parse.unquote(what))
        cat = "" if cat == "all" else f":category:{self.supported_categories[cat]}"
        parser = self.HTMLParser(self.url)
        current_page = 1
        max_pages = 5
        while current_page <= max_pages:
            url = "{0}get-posts/keywords:{1}{2}/?page={3}".format(
                self.url, what, cat, current_page
            )
            html = re.sub(r"\s+", " ", retrieve_url(url)).strip()
            parser.feed(html)
            if parser.noTorrents:
                break
            current_page += 1
            sleep(1)
