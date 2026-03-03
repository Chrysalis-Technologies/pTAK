# Frigate

## Description
Frigate is an open-source NVR (Network Video Recorder) focused on object detection using AI, integrating with Home Assistant for smart camera management.

## Features
- **AI Detection**: TensorFlow/OpenVINO for objects/people.
- **Zones/Clips**: Event-based recording.
- **Hardware Accel**: Coral TPU, GPU.
- **MQTT Output**: Events to HA.
- **Web UI**: Live views, timelines.
- **Storage Mgmt**: Auto-prune clips.

## Relevance to Current Build
In Hub Layer, processes feeds from Tapo/Wyze/Reolink cameras, integrating with Double-Take for face rec.

## Related Components
- [[Home Assistant Core]]: Integration.
- [[Double-Take]]: Face rec companion.
- [[Tapo cameras]]: Supported cameras.
- [[Wyze cameras]]: Integration.
- [[Reolink cameras]]: Feed source.
- [[Lorex NVR]]: Potential tie-in.
- [[MQTT integration]]: Event publishing.
- [[Docker]]: Deployment method.
