### PR Template

#### Name: [SUBSYSTEM] action: main objective

**Priority definitions**

**PRIORITY_SATANIC**:
Completely blocks startup, streaming, or deployment for the service. Requires
immediate resolution.

**PRIORITY_HIGH**:
Directly impacts camera service operation with no workaround. High risk of
stream outage, data loss, security exposure, or deployment failure.

**PRIORITY_MEDIUM**:
Affects operation but has a temporary workaround. Should be fixed in the next
release or planned maintenance pass.

**PRIORITY_LOW**:
Minor improvement, documentation, internal tooling, cleanup, or non-urgent work.

---

**Basic Info**

**Main Goal**: Briefly state the main objective of this PR.

---

**Summary of Changes**

- Added/fixed/improved X in Y to achieve Z.
- Refactored/removed/updated A for B reason.

---

**Docs Updated**

- List any documentation, diagrams, or resources updated as part of this PR.

---

**Future Steps**

- Mention follow-ups or pending tasks.
- Note any environment variable, deployment, or GitHub setting changes that must
  happen after merge.

---

**For QA / Verification**

- Test mode: local Docker Compose, remote server, edge device, or CI only.
- Streams affected: RTSP, WebRTC, HLS, demo source, USB camera, native RTSP.
- Hardware needed: server, Jetson, Raspberry Pi, USB camera, or none.

---

**PR Testing**

- [ ] Describe all initial conditions before starting the test.
- [ ] Describe all activities needed to verify this PR.
- [ ] Describe expected logs, stream behavior, UI behavior, or API responses.
- [ ] Include evidence needed to close the PR.
- [ ] Check relevant stream protocols when applicable.
- [ ] Check CPU, memory, and network impact when stream handling changes.
- [ ] Confirm no secrets or local-only config files were committed.

---

**Edge Cases**

- Note edge cases such as camera disconnects, invalid RTSP URLs, network loss,
  port conflicts, auth failures, or low-resource devices.
