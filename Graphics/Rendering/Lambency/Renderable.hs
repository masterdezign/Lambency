module Graphics.Rendering.Lambency.Renderable (
  RenderObject(..),
  Renderable(..),
  assignMaterial,
  switchMaterialTexture,
  createBasicRO,
  clearBuffers
  ) where

--------------------------------------------------------------------------------
import qualified Graphics.Rendering.OpenGL as GL
import Graphics.Rendering.Lambency.Shader
import Graphics.Rendering.Lambency.Material
import Graphics.Rendering.Lambency.Texture
import Graphics.Rendering.Lambency.Vertex

import qualified Data.Map as Map
import Data.Array.IO
import Data.Array.Storable
import Data.Int
import Foreign.Storable
import Foreign.Ptr
--------------------------------------------------------------------------------

data RenderObject = RenderObject {
  material :: Material,
  render :: Material -> IO ()
}

assignMaterial :: RenderObject -> Material -> RenderObject
assignMaterial o m = (\ro -> ro { material = m }) o

switchMaterialTexture :: RenderObject -> String -> Texture -> RenderObject
switchMaterialTexture ro name tex =
  (\o -> o { material = switchTexture (material ro) name tex }) ro

clearBuffers :: IO ()
clearBuffers = GL.clear [GL.ColorBuffer, GL.DepthBuffer]

createBasicRO :: [Vertex] -> [Int16] -> Material -> IO (RenderObject)
createBasicRO [] _ mat = do
  return $ RenderObject {
    material = mat,
    render = \_ -> return ()
  }
createBasicRO (v:vs) idxs mat =
  let
    flts :: [Float]
    flts = (v:vs) >>= toFloats
  in do
    vbo <- setupBuffer GL.ArrayBuffer flts
    ibo <- setupBuffer GL.ElementArrayBuffer idxs
    return $ RenderObject {
      material = mat,
      render = createRenderFunc vbo ibo $ fromIntegral (length idxs)
    }
  where
    ptrsize :: (Storable a) => [a] -> GL.GLsizeiptr
    ptrsize [] = toEnum 0
    ptrsize xs = toEnum $ length xs * (sizeOf $ head xs)

    setupBuffer :: (Storable a) => GL.BufferTarget -> [a] -> IO( GL.BufferObject )
    setupBuffer tgt xs = do
      buf <- GL.genObjectName
      GL.bindBuffer tgt GL.$= (Just buf)
      varr <- newListArray (0, length xs - 1) xs
      withStorableArray varr (\ptr -> GL.bufferData tgt GL.$= (ptrsize xs, ptr, GL.StaticDraw))
      return buf

    bindMaterial :: Material -> IO ()
    bindMaterial m = do
      mapM_ (\(loc, desc) -> GL.vertexAttribPointer loc GL.$= (GL.ToFloat, desc)) $
        zip (map lu $ getAttribNames v) (getDescriptors v)
     where
       lu :: String -> GL.AttribLocation
       lu name = let svs = (getShaderVars . getShader) m
          in case Map.lookup name svs of
            Nothing -> GL.AttribLocation (-1)
            Just var -> case var of
              Uniform _ _ -> GL.AttribLocation (-1)
              Attribute _ loc -> loc

    createRenderFunc :: GL.BufferObject -> GL.BufferObject ->
                        GL.NumArrayIndices -> (Material -> IO ())
    createRenderFunc vbo ibo nIndices = (\m -> do
        -- Bind appropriate buffers
        GL.bindBuffer GL.ArrayBuffer GL.$= Just vbo
        bindMaterial m

        GL.bindBuffer GL.ElementArrayBuffer GL.$= Just ibo

        -- Render
        GL.drawElements GL.Triangles nIndices GL.UnsignedShort nullPtr)

class Renderable a where
  createRenderObject :: a -> Material -> IO (RenderObject)

  defaultRenderObject :: a -> IO (RenderObject)
  defaultRenderObject m = createRenderObject m =<< createSimpleMaterial
