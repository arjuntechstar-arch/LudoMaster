"""Inspect the running Flutter Chrome preview through its local DevTools port."""
import argparse
import asyncio
import base64
import json
from pathlib import Path

import httpx
import websockets


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--screenshot", default="apps/mobile/build/ludo-play-web.png")
    parser.add_argument("--eval", default="document.title")
    parser.add_argument("--click-label")
    parser.add_argument("--fill-field", action="append", default=[], help="Accessible field label=value")
    parser.add_argument("--press-key", choices=["Escape", "Enter"])
    parser.add_argument("--click-at", help="Viewport coordinates x,y for an unlabeled control")
    parser.add_argument("--reload", action="store_true")
    parser.add_argument("--scroll-y", type=float, help="Scroll the app view using native browser input")
    parser.add_argument("--width", type=int, default=440)
    parser.add_argument("--height", type=int, default=960)
    args = parser.parse_args()
    targets = httpx.get(f"http://127.0.0.1:{args.port}/json").json()
    target = next(item for item in targets if item.get("url", "").startswith("http://localhost:8080"))
    async with websockets.connect(target["webSocketDebuggerUrl"], max_size=20_000_000) as ws:
        counter = 0
        errors = []
        async def command(method, params=None):
            nonlocal counter
            counter += 1
            message_id = counter
            await ws.send(json.dumps({"id": message_id, "method": method, "params": params or {}}))
            while True:
                reply = json.loads(await asyncio.wait_for(ws.recv(), timeout=30))
                if reply.get("method") == "Runtime.exceptionThrown":
                    details = reply["params"]["exceptionDetails"]
                    errors.append(details.get("exception", {}).get("description", details.get("text")))
                if reply.get("method") == "Network.loadingFailed":
                    errors.append(reply["params"].get("errorText"))
                if reply.get("id") == message_id:
                    if "error" in reply:
                        raise RuntimeError(reply["error"])
                    return reply.get("result", {})
        if args.reload:
            await command("Runtime.enable")
            await command("Network.enable")
            await command("Network.setCacheDisabled", {"cacheDisabled": True})
            await command("Page.reload", {"ignoreCache": True})
            await asyncio.sleep(10)
        await command("Emulation.setDeviceMetricsOverride", {
            "width": args.width, "height": args.height, "deviceScaleFactor": 1, "mobile": False,
        })
        await command("Emulation.setFocusEmulationEnabled", {"enabled": True})
        await command("Runtime.evaluate", {"expression": """
            window.previewNodes = function(selector) {
                const found = [];
                function visit(root) {
                    found.push(...root.querySelectorAll(selector));
                    root.querySelectorAll('*').forEach(el => { if (el.shadowRoot) visit(el.shadowRoot); });
                }
                visit(document); return found;
            };
            previewNodes('flt-semantics-placeholder')[0]?.click();
        """})
        await asyncio.sleep(2)
        if args.scroll_y:
            await command("Input.dispatchMouseEvent", {"type": "mouseWheel", "x": args.width / 2,
                "y": args.height / 2, "deltaX": 0, "deltaY": args.scroll_y})
            await asyncio.sleep(2)
        if args.press_key:
            for event_type in ["keyDown", "keyUp"]:
                await command("Input.dispatchKeyEvent", {"type": event_type, "key": args.press_key,
                    "code": args.press_key, "windowsVirtualKeyCode": 27 if args.press_key == "Escape" else 13})
            await asyncio.sleep(1)
        if args.click_at:
            point_x, point_y = map(float, args.click_at.split(","))
            for event_type in ["mousePressed", "mouseReleased"]:
                await command("Input.dispatchMouseEvent", {"type": event_type, "button": "left", "clickCount": 1,
                    "x": point_x, "y": point_y})
            await asyncio.sleep(1)
        for field in args.fill_field:
            label, value = field.split("=", 1)
            lookup = """(() => {
                const node = previewNodes('input,textarea').find(el => el.getAttribute('aria-label') === LABEL);
                if (!node) throw new Error('Field not found: ' + LABEL);
                const rect = node.getBoundingClientRect();
                return {x: rect.left + rect.width/2, y: rect.top + rect.height/2};
            })()""".replace("LABEL", json.dumps(label))
            location = await command("Runtime.evaluate", {"expression": lookup, "returnByValue": True})
            if "exceptionDetails" in location:
                raise RuntimeError(location["exceptionDetails"])
            coordinates = location["result"]["value"]
            for event_type in ["mousePressed", "mouseReleased"]:
                await command("Input.dispatchMouseEvent", {"type": event_type, "button": "left", "clickCount": 1, **coordinates})
            await asyncio.sleep(0.3)
            await command("Input.dispatchKeyEvent", {"type": "keyDown", "key": "a", "code": "KeyA", "modifiers": 2, "windowsVirtualKeyCode": 65})
            await command("Input.dispatchKeyEvent", {"type": "keyUp", "key": "a", "code": "KeyA", "modifiers": 0, "windowsVirtualKeyCode": 65})
            await command("Input.insertText", {"text": value})
            await asyncio.sleep(0.3)
        if args.click_label:
            lookup = """(() => {
                const node = previewNodes('[role=button], [role=tab], [role=switch], a[href]').find(el =>
                    (el.textContent || el.getAttribute('aria-label') || '').includes(LABEL));
                if (!node) throw new Error('Control not found: ' + LABEL);
                const rect = node.getBoundingClientRect();
                return {x: rect.left + rect.width/2, y: rect.top + rect.height/2};
            })()""".replace("LABEL", json.dumps(args.click_label))
            location = await command("Runtime.evaluate", {"expression": lookup, "returnByValue": True})
            if "exceptionDetails" in location:
                raise RuntimeError(location["exceptionDetails"])
            coordinates = location["result"]["value"]
            await command("Input.dispatchMouseEvent", {
                "type": "mousePressed", "button": "left", "clickCount": 1, **coordinates,
            })
            await command("Input.dispatchMouseEvent", {
                "type": "mouseReleased", "button": "left", "clickCount": 1, **coordinates,
            })
            await asyncio.sleep(1)
        result = await command("Runtime.evaluate", {
            "expression": args.eval, "returnByValue": True, "awaitPromise": True,
        })
        print(json.dumps(result, ensure_ascii=True))
        await asyncio.sleep(1)
        screenshot = await command("Page.captureScreenshot", {"format": "png"})
        path = Path(args.screenshot)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(base64.b64decode(screenshot["data"]))
        print(f"Screenshot saved: {path}")
        if errors:
            print(json.dumps({"browser_errors": errors}, ensure_ascii=True))


if __name__ == "__main__":
    asyncio.run(main())
