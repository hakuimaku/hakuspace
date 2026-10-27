#!/usr/bin/env python3
"""Exercise real ImageMagick exports against disposable raster fixtures."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import struct
import shutil
import time
import tempfile
import unittest
from unittest.mock import patch

# Load the production renderer without adding a dependency or an installed package.
ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("image_edit_ctl", ROOT / "src/core/backend/media/image_edit_ctl.py")
backend = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(backend)


class BackendTests(unittest.TestCase):
    """Check pixels, transforms, preservation and validation at the export boundary."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source # with space.png"
        subprocess.run(["magick", "-size", "80x40", "xc:white", "-fill", "red", "-draw", "rectangle 0,0 39,19", str(self.source)], check=True)
        self.original = self.source.read_bytes()

    def spec(self, **changes):
        value = dict(sourcePath=str(self.source), fingerprint=backend.fingerprint(self.source), mode="file",
                     outputPath=str(self.root / "edited.png"), rotation=0, flipX=False, flipY=False,
                     cropRectNormalized=dict(x=0, y=0, width=1, height=1), annotations=[], outputScale=1, encodeQuality=90)
        return value | changes

    def pixel(self, path, x, y):
        return subprocess.check_output(["magick", str(path), "-format", f"%[pixel:p{{{x},{y}}}]", "info:"], text=True)

    def test_inspect_crop_scale_and_original_preserved(self):
        info = backend.inspect(str(self.source))
        self.assertEqual((info["width"], info["height"], info["mime"]), (80, 40, "image/png"))
        result = backend.render(self.spec(cropRectNormalized=dict(x=.25,y=0,width=.5,height=1),outputScale=.75))
        self.assertEqual((result["width"], result["height"]), (30,30))
        self.assertEqual(self.source.read_bytes(),self.original)
        self.assertFalse(list(self.root.glob('.hikai-edit-*')))

    def test_orientation_then_annotation_then_crop(self):
        arrow = dict(type="arrow",start=dict(x=.1,y=.5),end=dict(x=.9,y=.5),width=.1,color="#0000ff",opacity=1)
        result = backend.render(self.spec(rotation=90,flipX=True,annotations=[arrow]))
        path = Path(result["path"])
        self.assertEqual((result["width"],result["height"]),(40,80))
        self.assertIn('255,0,0', self.pixel(path,5,5))
        self.assertIn('0,0,255', self.pixel(path,20,40))

    def test_exif_orientation_and_literal_path_characters(self):
        jpeg = self.root / "photo [1] #.jpg"
        subprocess.run(["magick",str(self.source),str(jpeg)],check=True)
        exif = b"Exif\0\0MM\0*\0\0\0\x08" + struct.pack(">H",1) + struct.pack(">HHI",0x112,3,1) + struct.pack(">H",6) + b"\0\0\0\0\0\0"
        original = jpeg.read_bytes()
        jpeg.write_bytes(original[:2]+b"\xff\xe1"+struct.pack(">H",len(exif)+2)+exif+original[2:])
        info = backend.inspect(str(jpeg))
        self.assertEqual((info['width'],info['height']),(40,80))
        result = backend.render(self.spec(sourcePath=str(jpeg),fingerprint=info['fingerprint']))
        self.assertEqual((result['width'],result['height']),(40,80))

    def test_avatar_is_square_png(self):
        result = backend.render(self.spec(mode="avatar",cropRectNormalized=dict(x=.25,y=0,width=.5,height=1)))
        self.assertEqual((result["width"],result["height"]),(512,512))
        self.assertEqual(backend.inspect(result['path'])['format'],'PNG')
        with self.assertRaises(ValueError):
            backend.render(self.spec(mode="avatar",outputPath=str(self.root/'bad.png')))

    def test_stroke_and_lossy_encoders(self):
        stroke = dict(type="stroke",points=[dict(x=.1,y=.7),dict(x=.9,y=.7)],width=.05,color="#00ff00",opacity=1)
        for extension in ('.png','.jpg','.webp'):
            path = self.root / ('stroke'+extension)
            result = backend.render(self.spec(outputPath=str(path), annotations=[stroke], encodeQuality=75))
            self.assertEqual(result['width'],80)
            self.assertTrue(path.is_file())
        self.assertIn('0,255,0',self.pixel(self.root/'stroke.png',40,28))

    def test_reject_invalid_specs_and_keep_outputs(self):
        destination = self.root / 'edited.png'
        for changes in [dict(rotation=45),dict(outputScale=float('nan')),
                        dict(cropRectNormalized=dict(x=.9,y=0,width=.5,height=1)),
                        dict(fingerprint='stale'),dict(outputPath=str(self.source)),
                        dict(annotations=[dict(type='stroke',points=[dict(x=.2,y=.2)],color='url(file:///tmp/a)',width=.01,opacity=1)])]:
            with self.assertRaises(ValueError): backend.render(self.spec(**changes))
            self.assertFalse(destination.exists())
            self.assertEqual(self.source.read_bytes(),self.original)
        destination.write_bytes(b'existing')
        with self.assertRaises(ValueError): backend.render(self.spec())
        self.assertEqual(destination.read_bytes(),b'existing')
        destination.unlink(); destination.symlink_to(self.source)
        with self.assertRaises(ValueError): backend.render(self.spec())

    def test_missing_unsupported_and_changed_sources(self):
        for path in (self.root/'missing.png', self.root/'vector.svg'):
            if path.suffix == '.svg': path.write_text('<svg xmlns="http://www.w3.org/2000/svg"/>')
            with self.assertRaises(ValueError): backend.inspect(str(path))
        value = self.spec()
        self.source.write_bytes(self.original+b'changed')
        with self.assertRaises(ValueError): backend.render(value)

    def test_8k_source_downscales_at_export(self):
        large = self.root / '8k.png'
        subprocess.run(['magick','-limit','thread','2','-size','7680x4320','xc:navy',str(large)],check=True)
        result = backend.render(self.spec(sourcePath=str(large),fingerprint=backend.fingerprint(large),outputScale=.5))
        self.assertEqual((result['width'],result['height']),(3840,2160))
        self.assertEqual(backend.inspect(str(large))['width'],7680)

    def test_render_failure_preserves_screenshot(self):
        value = self.spec(mode='screenshot',outputPath=str(self.source),annotations=[dict(type='unknown')])
        with self.assertRaises((ValueError,KeyError)): backend.render(value)
        self.assertEqual(self.source.read_bytes(), self.original)
        real_run = backend.run
        def fail_render(args, **kwargs):
            if args[0] == 'magick' and 'identify' not in args:
                raise subprocess.CalledProcessError(1,args)
            return real_run(args,**kwargs)
        with patch.object(backend,'run',side_effect=fail_render):
            with self.assertRaises(subprocess.CalledProcessError):
                backend.render(self.spec(mode='screenshot',outputPath=str(self.source)))
        self.assertEqual(self.source.read_bytes(), self.original)
        self.assertFalse(list(self.root.glob('.hikai-edit-*')))

    def test_interrupted_export_removes_staged_output(self):
        tools = self.root/'slow-tools'; tools.mkdir()
        marker = self.root/'render-started'
        script = tools/'magick'
        script.write_text('#!/usr/bin/env python3\nimport os,sys,time\nfrom pathlib import Path\n'
                          + 'if sys.argv[1] == "identify": os.execv(' + repr(shutil.which('magick')) + ',sys.argv)\n'
                          + 'Path(' + repr(str(marker)) + ').touch()\ntime.sleep(60)\n')
        script.chmod(0o755)
        spec_path = self.root/'interrupt.json'
        spec_path.write_text(json.dumps(self.spec(mode='screenshot',outputPath=str(self.source))))
        process = subprocess.Popen(['python3',str(ROOT/'src/core/backend/media/image_edit_ctl.py'),'render',str(spec_path)],
                                   env={**os.environ,'PATH':str(tools)+os.pathsep+os.environ['PATH']},stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic()+5
            while not marker.exists() and time.monotonic()<deadline:
                time.sleep(.02)
            self.assertTrue(marker.exists(),'renderer did not start')
            process.terminate()
            process.communicate(timeout=5)
            self.assertNotEqual(process.returncode,0)
        finally:
            if process.poll() is None:
                process.kill(); process.communicate()
        self.assertEqual(self.source.read_bytes(),self.original)
        self.assertFalse(list(self.root.glob('.hikai-edit-*')))

    def test_screenshot_background_clipboard_does_not_hold_export_open(self):
        tools = self.root/'fork-tools'; tools.mkdir()
        clipboard = self.root/'forked-clipboard.png'
        script = tools/'wl-copy'
        # Match wl-copy's detached owner: stdout closes, stderr stays inherited.
        script.write_text('#!/usr/bin/env python3\nimport os,sys,time\nfrom pathlib import Path\n'
                          + 'Path(os.environ["IMAGE_EDITOR_CLIPBOARD"]).write_bytes(sys.stdin.buffer.read())\n'
                          + 'with open(os.devnull,"wb") as null: os.dup2(null.fileno(),1)\n'
                          + 'if os.fork() == 0:\n    time.sleep(2)\n    os._exit(0)\n')
        script.chmod(0o755)
        real_run = subprocess.run
        def bounded_copy(args, **kwargs):
            if args[0] == 'wl-copy': kwargs['timeout'] = .5
            return real_run(args,**kwargs)
        with patch.dict(os.environ,{'PATH':str(tools)+os.pathsep+os.environ['PATH'],'IMAGE_EDITOR_CLIPBOARD':str(clipboard)}):
            with patch.object(backend.subprocess,'run',side_effect=bounded_copy):
                result = backend.render(self.spec(mode='screenshot',outputPath=str(self.source),outputScale=.5))
        self.assertEqual(clipboard.read_bytes(),self.source.read_bytes())
        self.assertEqual(result['warning'],'')

    def test_screenshot_clipboard_failure_preserves_successful_save(self):
        tools = self.root/'failed-copy'; tools.mkdir()
        script = tools/'wl-copy'; script.write_text('#!/bin/sh\nexit 1\n'); script.chmod(0o755)
        with patch.dict(os.environ,{'PATH':str(tools)+os.pathsep+os.environ['PATH']}):
            result = backend.render(self.spec(mode='screenshot',outputPath=str(self.source),outputScale=.5))
        self.assertEqual((result['width'],result['height']),(40,20))
        self.assertIn('Image saved',result['warning'])
        self.assertEqual(backend.inspect(str(self.source))['width'],40)
        self.assertFalse(list(self.root.glob('.hikai-edit-*')))

    def test_screenshot_atomic_replace_and_clipboard(self):
        tools = self.root/'bin'; tools.mkdir()
        clipboard = self.root/'clipboard.png'
        script = tools/'wl-copy'
        script.write_text('#!/bin/sh\ncat > "$IMAGE_EDITOR_CLIPBOARD"\n')
        script.chmod(0o755)
        environment = {**os.environ, 'PATH':str(tools)+os.pathsep+os.environ['PATH'],'IMAGE_EDITOR_CLIPBOARD':str(clipboard)}
        spec_path = self.root/'spec.json'
        spec_path.write_text(json.dumps(self.spec(mode='screenshot',outputPath=str(self.source),outputScale=.5)))
        result = subprocess.run(['python3',str(ROOT/'src/core/backend/media/image_edit_ctl.py'),'render',str(spec_path)],env=environment,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(clipboard.read_bytes(),self.source.read_bytes())
        self.assertEqual((backend.inspect(str(self.source))['width']),40)
        self.assertFalse(list(self.root.glob('.hikai-edit-*')))


if __name__ == '__main__':
    unittest.main()
