### Magic Link Authentication (Email)

- [x] Backend settings & env variables (`RESEND_API_KEY`, `MAGIC_LINK_VERIFY_URL`, `MAGIC_LINK_EXPIRY_MINUTES`)
- [x] `MagicLink` model with hashed single-use token & expiry
- [x] Creation & email sending via Resend (fallback to Django email backend)
- [x] Request endpoint `POST /api/auth/magic/request/` (returns 202)
- [x] Verify endpoint `POST /api/auth/magic/verify/` (issues JWT access/refresh)
- [x] Debug token echo in response when `DEBUG && MAGIC_LINK_DEBUG_ECHO_TOKEN`
- [x] Automatic user creation on first successful verification (signup-on-use)
- [x] Email includes code and clickable link
- [x] Token persistence & auth state refresh post verification
- [ ] Frontend integration (Flutter customer app) — service stub to be added
- [ ] Rate limiting refinement (custom scope) & abuse monitoring
- [ ] Optional: store last login time from magic link

# Feature Implementation Checklist
---

- [x] ✅ Email integration via Django-Anymail
- [x] ✅ JWT authentication (token obtain/refresh/verify)
### API Endpoints (Public/Customer)
- [x] ✅ `/api/v1/me` - Get current user
- [ ] ⬜ Membership management endpoints
- [ ] ⬜ Notification list/read endpoints
- [x] ✅ `/admin/api/push/test/` - Send test push notification
- [x] ✅ Admin throttling configured (`admin` scope)
- [x] ✅ Session/CSRF middleware
- [ ] ⬜ Rate limit headers (X-RateLimit-*)
- [ ] ⬜ Serializer tests
- [ ] ⬜ Integration tests
- [ ] ⬜ API schema validation tests

### Optional Backend Features ⚙️
- [ ] ⚙️ Feature flag service integration
- [ ] ⚙️ Multi-factor authentication (MFA)
- [ ] ⬜ OpenAPI-generated client (currently manual)

- [ ] ⬜ Email verification UI
- [ ] ⬜ Profile management screen
- [ ] ⬜ MFA UI
- [ ] ⬜ Organization management UI
- [ ] ⬜ Team member invitation

- [ ] ⬜ Widget unit tests
- [ ] ⬜ State provider tests
- [ ] ⬜ Integration tests (flutter drive)
- [ ] ⬜ Golden tests (visual regression)
- [ ] ⚙️ Direct object storage uploads
- [ ] ⚙️ Analytics integration (Segment/Firebase)

### Admin Features
- [ ] ⬜ Feature toggle management UI
- [ ] ⬜ Maintenance task triggers
- [ ] ⬜ System health monitoring
- [ ] ⬜ Audit log viewer
- [ ] ⬜ API key management
- [ ] ⚙️ Advanced search and filtering
- [ ] ⚙️ Export functionality (CSV, PDF)
## iOS App

- [ ] ⬜ App Store Connect setup

### iOS Features
- [ ] ⬜ Deep linking support
- [ ] ⬜ Universal links
- [ ] ⚙️ Biometric authentication (Face ID/Touch ID)
- [ ] ⚙️ iOS-specific UI adaptations
## Android App

- [ ] ⬜ Google Play Console setup

### Android Features
- [ ] ⬜ Deep linking support
- [ ] ⬜ App links
- [ ] ⚙️ Release track configuration
- [ ] ⚙️ Biometric authentication
- [ ] ⬜ .dockerignore files

- [ ] ⬜ ConfigMaps for configuration
- [ ] ⬜ Secrets management
- [ ] ⬜ Component enable/disable toggles
- [ ] ⬜ Chart documentation
- [ ] ⬜ Docker image build pipeline
- [ ] ⬜ Container registry push
- [ ] ⬜ docker-compose with Postgres
- [ ] ⬜ docker-compose with Redis
- [ ] ⚙️ Log aggregation
- [ ] ⚙️ Alerting rules
- [ ] ⚙️ Tracing implementation

### Optional Infrastructure ⚙️
- [ ] ⚙️ cert-manager for TLS
- [ ] ⚙️ VPA (Vertical Pod Autoscaler)

### Documentation
- [x] ✅ Pre-commit tooling (07-precommit-tooling.md)
- [ ] ⬜ API reference (generated)
- [ ] ⬜ Architecture diagrams
- [ ] ⬜ Deployment runbooks
### Developer Experience
- [ ] ⬜ Makefile with common commands
- [ ] ⬜ Setup scripts
- [ ] ⬜ Database migration helpers
- [ ] ⬜ Test data generators
- [ ] ⬜ API client generation script
- [ ] ⬜ Development environment validation

---

## Notes

- This checklist reflects the current state as of December 2025
- Features marked with ⚙️ are optional and can be enabled based on project needs
- Update this document as features are completed or new features are identified
- For detailed implementation guidance, refer to the specific documentation files referenced in each section
