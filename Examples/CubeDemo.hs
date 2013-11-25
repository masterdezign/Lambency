module Main (main) where

--------------------------------------------------------------------------------

import qualified Graphics.UI.Lambency as L
import qualified Graphics.Rendering.Lambency as LR

import Data.Vect.Float
import Data.Vect.Float.Util.Quaternion

import Data.Maybe (fromJust)
import qualified Data.Map as Map

import System.Directory
import System.FilePath
import Paths_lambency_examples

import GHC.Float (double2Float)
---------------------------------------------------------------------------------

data CubeDemoObject = DemoObject Float Vec3 UnitQuaternion

demoCam :: LR.Camera
demoCam = LR.mkPerspCamera
           -- Pos           Dir              Up
           ((-15) *& vec3Z) (mkNormal (vec3Z)) (mkNormal vec3Y)
           (pi / 4) (4.0 / 3.0)
           -- near far
           0.1 1000.0

demoSVMap :: Map.Map String (CubeDemoObject -> LR.Camera -> LR.ShaderValue)
demoSVMap = Map.fromList [
  ("mvpMatrix", updateMVPMatrix),
  ("m2wMatrix", updateModelMatrix)]
  where
    updateModelMatrix :: CubeDemoObject -> LR.Camera -> LR.ShaderValue
    updateModelMatrix (DemoObject scale pos rot) c =
      LR.Matrix4Val $ LR.sprToMatrix scale pos rot

    updateMVPMatrix :: CubeDemoObject -> LR.Camera -> LR.ShaderValue
    updateMVPMatrix obj c = LR.Matrix4Val $ model .*. (LR.getViewProjMatrix c)
      where (LR.Matrix4Val model) = updateModelMatrix obj c

planeObj :: LR.Material -> IO (LR.GameObject CubeDemoObject)
planeObj mat = do
  ro <- LR.createRenderObject LR.makePlane mat
  return LR.GameObject {
    LR.renderObject = Just ro,
    LR.gameObject = DemoObject 10 (Vec3 0 (-2) 0) unitU,
    LR.objSVMap = demoSVMap,
    LR.update = \_ o _ -> Just o
  }

cubeObj :: LR.Material -> IO (LR.GameObject CubeDemoObject)
cubeObj mat = do
  (Just tex) <- getDataFileName ("crate" <.> "png") >>= LR.loadTextureFromPNG
  ro <- LR.createRenderObject LR.makeCube (LR.switchTexture mat "diffuseTex" tex)
  return LR.GameObject {
    LR.renderObject = Just ro,
    LR.gameObject = DemoObject 1 zero $ rotU (Vec3 1 0 1) 0.6,
    LR.objSVMap = demoSVMap,
    LR.update = \t obj _ -> Just $ rotateObj t obj
  }
  where 
  rotateObj dt (DemoObject s p u) = DemoObject s p $ u .*. (rotU vec3Y $ double2Float dt)

main :: IO ()
main = do
  m <- L.makeWindow 640 480 "Cube Demo"
  mat <- LR.createSpotlightMaterial . Just =<< (LR.createSolidTexture (128, 128, 128, 255))
  objs <- sequence [cubeObj mat, planeObj mat]
  case m of
    (Just win) -> L.run win (LR.GameCamera demoCam $ flip const) objs
    Nothing -> return ()
  L.destroyWindow m
