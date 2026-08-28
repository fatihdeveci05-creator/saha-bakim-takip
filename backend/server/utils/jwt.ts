import { SignJWT, jwtVerify } from 'jose'

export interface AuthTokenPayload {
  sub: string // user id
  taraf: 'isveren' | 'alt_yuklenici'
  rol: string
}

function getSecret() {
  const secret = useRuntimeConfig().jwtSecret
  if (!secret) throw new Error('JWT_SECRET tanımlı değil')
  return new TextEncoder().encode(secret)
}

export async function signAccessToken(payload: AuthTokenPayload) {
  return new SignJWT({ taraf: payload.taraf, rol: payload.rol })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(payload.sub)
    .setIssuedAt()
    .setExpirationTime('15m')
    .sign(getSecret())
}

export async function signRefreshToken(payload: AuthTokenPayload) {
  return new SignJWT({ taraf: payload.taraf, rol: payload.rol })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(payload.sub)
    .setIssuedAt()
    .setExpirationTime('30d')
    .sign(getSecret())
}

export async function verifyToken(token: string): Promise<AuthTokenPayload> {
  const { payload } = await jwtVerify(token, getSecret())
  return {
    sub: payload.sub!,
    taraf: payload.taraf as AuthTokenPayload['taraf'],
    rol: payload.rol as string,
  }
}
