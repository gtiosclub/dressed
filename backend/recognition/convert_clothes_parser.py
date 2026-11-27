"""Convert the SegFormer clothes-parsing weights to a quantized Core ML package.

EVALUATION ONLY. The weights derive from NVIDIA's SegFormer, whose source code
license limits use to research or evaluation, and were trained on the ATR human
parsing dataset. Do not commit or ship the output without lead approval.

Setup and use: see "Clothes parsing" in backend/recognition/README.md.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import coremltools as ct
import coremltools.optimize.coreml as optimize
import numpy as np
import torch
from PIL import Image
from transformers import SegformerForSemanticSegmentation

SIZE = 512
# Order must match ClothesParser.Label in dressed/Camera/ViewModels/ClothesParser.swift.
LABELS = ["Background", "Hat", "Hair", "Sunglasses", "Upper-clothes", "Skirt", "Pants",
          "Dress", "Belt", "Left-shoe", "Right-shoe", "Face", "Left-leg", "Right-leg",
          "Left-arm", "Right-arm", "Bag", "Scarf"]


class LabelMap(torch.nn.Module):
    """RGB in 0...1 to one label per pixel, so the app does no tensor math."""

    def __init__(self, model: torch.nn.Module):
        super().__init__()
        self.model = model
        self.register_buffer("mean", torch.tensor([0.485, 0.456, 0.406]).view(1, 3, 1, 1))
        self.register_buffer("std", torch.tensor([0.229, 0.224, 0.225]).view(1, 3, 1, 1))

    def forward(self, image: torch.Tensor) -> torch.Tensor:
        logits = self.model(pixel_values=(image - self.mean) / self.std, return_dict=False)[0]
        logits = torch.nn.functional.interpolate(logits, size=(SIZE, SIZE),
                                                 mode="bilinear", align_corners=False)
        return torch.argmax(logits, dim=1).to(torch.int32)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("weights", type=Path,
                        help="directory with config.json and model.safetensors")
    parser.add_argument("output", type=Path, help="output .mlpackage path (outside the app)")
    parser.add_argument("--check-image", type=Path, action="append", default=[],
                        help="compare PyTorch and Core ML labels on this photo (macOS)")
    args = parser.parse_args()

    model = SegformerForSemanticSegmentation.from_pretrained(
        args.weights, use_safetensors=True, local_files_only=True)
    found = [model.config.id2label[index] for index in range(len(model.config.id2label))]
    if found != LABELS:
        raise SystemExit(f"unexpected labels: {found}")
    wrapper = LabelMap(model).eval()
    with torch.no_grad():
        traced = torch.jit.trace(wrapper, torch.rand(1, 3, SIZE, SIZE))
    package = ct.convert(
        traced, convert_to="mlprogram", minimum_deployment_target=ct.target.iOS17,
        inputs=[ct.ImageType(name="image", shape=(1, 3, SIZE, SIZE), scale=1 / 255)],
        outputs=[ct.TensorType(name="labels")])
    package = optimize.linear_quantize_weights(package, config=optimize.OptimizationConfig(
        global_config=optimize.OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int8")))
    package.short_description = "Clothes parsing (evaluation only; see license note)"
    package.license = "NVIDIA SegFormer: research or evaluation use only"
    package.save(str(args.output))
    size = sum(f.stat().st_size for f in args.output.rglob("*") if f.is_file())
    print(f"saved {args.output} ({size / 1_000_000:.1f} MB)")

    for path in args.check_image:
        image = Image.open(path).convert("RGB").resize((SIZE, SIZE), Image.BILINEAR)
        pixels = torch.from_numpy(np.array(image).copy()).permute(2, 0, 1)[None].float() / 255
        with torch.no_grad():
            expected = wrapper(pixels).numpy()
        actual = package.predict({"image": image})["labels"]
        print(f"{path.name}: {100 * (expected == actual).mean():.2f}% pixels agree")


if __name__ == "__main__":
    main()
