package com.pblabs.nape
{
	import com.pblabs.engine.PBE;
	import com.pblabs.engine.PBUtil;
	import com.pblabs.engine.core.IAnimatedObject;
	import com.pblabs.engine.core.ITickedObject;
	import com.pblabs.engine.core.ObjectType;
	import com.pblabs.engine.debug.Logger;
	import com.pblabs.engine.entity.EntityComponent;
	import com.pblabs.physics.IPhysics2DManager;
	import com.pblabs.rendering2D.BasicSpatialManager2D;
	import com.pblabs.rendering2D.ISpatialManager2D;
	import com.pblabs.rendering2D.ISpatialObject2D;
	import com.pblabs.rendering2D.RayHitInfo;
	
	import flash.display.DisplayObject;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import nape.callbacks.CbEvent;
	import nape.callbacks.CbType;
	import nape.callbacks.InteractionCallback;
	import nape.callbacks.InteractionListener;
	import nape.callbacks.InteractionType;
	import nape.callbacks.PreCallback;
	import nape.callbacks.PreListener;
	import nape.dynamics.Arbiter;
	import nape.dynamics.InteractionFilter;
	import nape.geom.AABB;
	import nape.geom.Ray;
	import nape.geom.RayResult;
	import nape.geom.Vec2;
	import nape.phys.Body;
	import nape.phys.BodyList;
	import nape.phys.Material;
	import nape.space.Broadphase;
	import nape.space.Space;
	import nape.util.ShapeDebug;
	
	import org.osmf.logging.Log;

	public class NapeManagerComponent extends EntityComponent implements ITickedObject, IAnimatedObject, IPhysics2DManager
	{
		public function NapeManagerComponent()
		{
			super();
		}
		
		public function get space():Space
		{
			return _space;
		}
		
		[EditorData(defaultValue="30")]
		public function get scale():Number
		{
			return _scale;
		}
		
		public function set scale(value:Number):void
		{
			_scale = value;
		}
		
		public function get inverseScale():Number
		{
			return 1 / _scale;
		}
		public function get gravity():Point
		{
			return _gravity;
		}
		
		public function set gravity(value:Point):void
		{
			_gravity = value;
			
			if ( _space )
				_space.gravity.setxy(_gravity.x, _gravity.y);
		}
		
		public function get materialManager():NapeMaterialManager
		{
			return _materialManager;
		}
		
		public function set materialManager(value:NapeMaterialManager):void
		{
			if (_materialManager)
				throw new Error("Material manager already set!");
			_materialManager = value;
		}
		
		public function get visualDebugging():Boolean
		{
			return _visualDebugging;
		}
		
		public function set visualDebugging(value:Boolean):void
		{
			_visualDebugging = value;
			if(!_shapeDebug) 
				return;
			
			if(_visualDebugging)
				_shapeDebug.draw(_space);
			else
				_shapeDebug.clear();
		}
		
		public function get debugDrawer() : DisplayObject
		{
			if(!_shapeDebug)
				return null;
			return _shapeDebug.display;
		}

		public function get bodyCallbackType():CbType
		{
			return _bodyCallbackType;
		}
		
		[EditorData(defaultValue="true")]
		public function get allowSleep():Boolean
		{
			return _allowSleep;
		}
		
		public function set allowSleep(value:Boolean):void
		{
		
		}
		
		[EditorData(defaultValue="-10000|-10000|20000|20000")]
		public function get worldBounds():Rectangle
		{
			return _worldBounds;
		}
		
		public function set worldBounds(value:Rectangle):void
		{
			if (_space)
			{
				Logger.warn(this, "WorldBounds", "This property cannot be changed once the world has been created!");
				return;
			}
			/*_worldBounds.x = _space.world.bounds.x*scale;
			_worldBounds.y = _space.world.bounds.y*scale;
			_worldBounds.width = _space.world.bounds.width*scale;
			_worldBounds.height = _space.world.bounds.height*scale;*/
			_worldBounds = value;
		}

		public function onTick(dt:Number):void
		{
			_space.step(dt);
		}
		
		public function onFrame(dt:Number):void
		{
			if(_shapeDebug && _visualDebugging){
				_shapeDebug.clear();
				_shapeDebug.transform.setAs(scale, 0, 0, scale, 0, 0);
				_shapeDebug.draw(_space);
				_shapeDebug.flush();
			}
		}
		
		public function addSpatialObject(object:ISpatialObject2D):void
		{
			_otherItems.addSpatialObject(object);
		}
		
		public function removeSpatialObject(object:ISpatialObject2D):void
		{
			_otherItems.removeSpatialObject(object);
		}
		
		public function queryRectangle(box:Rectangle, mask:ObjectType, results:Array):Boolean
		{
			//query aabb
			var aabb:AABB = new AABB(box.left*inverseScale, box.top*inverseScale, box.width*inverseScale, box.height*inverseScale);
			//setup filter
			var queryInteractionFilter:InteractionFilter = new InteractionFilter(-1, (mask ? mask.bits : -1));
			
			var numFoundBodies:int;
			
			var bodyList:BodyList = _space.bodiesInAABB(aabb, false, true, queryInteractionFilter);
			
			numFoundBodies = bodyList.length;
			bodyList.foreach(function (item:Body):void
			{
				var curComponent:NapeSpatialComponent = item.userData.spatial;
				if ( !curComponent )	//so what should we do? is it even possible?
				{
					Logger.error(this, "queryRectangle", "Body user data must contain spatialComponent!");
					return;
				}
				results.push(curComponent);				
			});
			
			// Let the other items have a turn.
			numFoundBodies += _otherItems.queryRectangle(box, mask, results) ? 1 : 0;
			
			// If we made it anywhere with i, then we got a result.
			return (numFoundBodies != 0);
			
			return false;
		}
		
		public function queryCircle(center:Point, radius:Number, mask:ObjectType, results:Array):Boolean
		{
			//query aabb
			var pos:Vec2 = new Vec2(center.x*inverseScale, center.y*inverseScale);
			//setup filter
			var queryInteractionFilter:InteractionFilter = new InteractionFilter(-1, (mask ? mask.bits : -1));
			
			var numFoundBodies:int;
			
			var bodyList:BodyList = _space.bodiesInCircle(pos, radius*inverseScale, false, queryInteractionFilter);
			
			numFoundBodies = bodyList.length;
			bodyList.foreach(function (item:Body):void
			{
				var curComponent:NapeSpatialComponent = item.userData.spatial;
				if ( !curComponent )	//so what should we do? is it even possible?
				{
					Logger.error(this, "queryCircle", "Body user data must contain spatialComponent!");
					return;
				}
				results.push(curComponent);				
			});
			
			// Let the other items have a turn.
			numFoundBodies += _otherItems.queryCircle(center, radius, mask, results)  ? 1 : 0;
			
			// If we made it anywhere with i, then we got a result.
			return (numFoundBodies != 0);
			
			return false;
		}
		
		public function castRay(start:Point, end:Point, mask:ObjectType, result:RayHitInfo):Boolean
		{
			var ray:Ray = Ray.fromSegment(new Vec2(start.x*inverseScale, start.y*inverseScale), new Vec2(end.x*inverseScale, end.y*inverseScale));
			var queryInteractionFilter:InteractionFilter = new InteractionFilter(-1, (mask ? mask.bits : -1));
			var napeResult:RayResult = _space.rayCast(ray, false, queryInteractionFilter);
			if ( napeResult )
			{
				//convert nape result to RayHitInfo
				result.time = napeResult.distance/ray.maxDistance;
				result.normal = new Point(napeResult.normal.x, napeResult.normal.y);
				var contact:Vec2 = ray.at(napeResult.distance);
				result.position = new Point(contact.x*_scale, contact.y*_scale);
				result.hitObject = napeResult.shape.body.userData.spatial;
				return true;
			}
			return _otherItems.castRay(start, end, mask, result);
		}
		
		/**
		 * @inheritDoc
		 */
		public function getObjectsUnderPoint(worldPosition:Point, results:Array, mask:ObjectType = null):Boolean
		{
			var tmpResults:Array = new Array();
			var queryInteractionFilter:InteractionFilter = new InteractionFilter(-1, (mask ? mask.bits : -1));
			var numFoundBodies:int;
			var bodyList:BodyList = _space.bodiesUnderPoint(new Vec2(worldPosition.x*inverseScale, worldPosition.y*inverseScale), queryInteractionFilter);
			
			numFoundBodies = bodyList.length;
			bodyList.foreach(function (item:Body):void
			{
				var curComponent:NapeSpatialComponent = item.userData.spatial;
				if ( !curComponent )	//so what should we do? is it even possible?
				{
					Logger.error(this, "getObjectsUnderPoint", "Body user data must contain spatialComponent!");
					return;
				}
				results.push(curComponent);				
			});
			
			// Let the other items have a turn.
			numFoundBodies += _otherItems.getObjectsUnderPoint(worldPosition, results, mask)  ? 1 : 0;
			
			// If we made it anywhere with i, then we got a result.
			return (numFoundBodies != 0);
			
			return false;
		}
		
		/**
		 * Grab all spatials within a rectangular region
		 */
		public function getObjectsInRec(worldRec:Rectangle, results:Array):Boolean
		{
			var tmpResults:Array = new Array();
			
			// First use the normal spatial query...
			queryRectangle(worldRec, null, tmpResults);
			
			// Ok, now pass control to the objects and see what they think.
			return _otherItems.getObjectsInRec(worldRec, results);
		}

		override protected function onAdd():void
		{
			super.onAdd();
			_bodyCallbackType = new CbType();
			//provide default material manager
			if (!_materialManager)
				_materialManager = new NapeMaterialManager();
			PBE.processManager.addTickedObject(this);
			PBE.processManager.addAnimatedObject(this);
			initSpace();
		}
		
		override protected function onRemove():void
		{
			freeSpace();
			PBE.processManager.removeTickedObject(this);
			PBE.processManager.removeAnimatedObject(this);
			super.onRemove();
		}
		
		private function initSpace():void
		{
			_space = new Space(new Vec2(_gravity.x, _gravity.y), Broadphase.DYNAMIC_AABB_TREE);
			//we don't need it now
			//_space.listeners.add(new PreListener(InteractionType.COLLISION, _bodyCallbackType, _bodyCallbackType, preCollisionCallback));
			_space.listeners.add(new InteractionListener(CbEvent.BEGIN, InteractionType.COLLISION, _bodyCallbackType, _bodyCallbackType, beginCollisionCallback));
			_space.listeners.add(new InteractionListener(CbEvent.END, InteractionType.COLLISION, _bodyCallbackType, _bodyCallbackType, endCollisionCallback));
			_space.listeners.add(new InteractionListener(CbEvent.ONGOING, InteractionType.COLLISION, _bodyCallbackType, _bodyCallbackType, ongoingCollisionCallback));
			
			_shapeDebug = new ShapeDebug(PBUtil.clamp(PBE.mainClass.width, 10, 5000000), PBUtil.clamp(PBE.mainClass.height, 10, 5000000), 0x4D4D4D );
			//_shapeDebug.drawShapeDetail = true;
			_shapeDebug.drawConstraints = true;
			//_shapeDebug.drawBodyDetail = true;
		}
		
		private function freeSpace():void
		{
			_space.listeners.clear();
			_space.clear();
			
			if(_shapeDebug)
				_shapeDebug.clear();
		}
		
		/*private function preCollisionCallback(cb:PreCallback):void
		{
			if ( cb.arbiter.isCollisionArbiter() )
			{
				var ce:CollisionEvent = new CollisionEvent(COllisionev
				cb.arbiter.collisionArbiter.normal
			}
		}*/
		
		private function beginCollisionCallback(cb:InteractionCallback):void
		{
			cb.arbiters.foreach(function (item:Arbiter):void
			{
				dispatchCollisionEvents(item, CollisionEvent.COLLISION_EVENT);
			});
		}
		
		private function endCollisionCallback(cb:InteractionCallback):void
		{
			cb.arbiters.foreach(function (item:Arbiter):void
			{
				dispatchCollisionEvents(item, CollisionEvent.COLLISION_STOPPED_EVENT);
			});
		}
		
		private function ongoingCollisionCallback(cb:InteractionCallback):void
		{
			cb.arbiters.foreach(function (item:Arbiter):void
			{
				dispatchCollisionEvents(item, CollisionEvent.ONGOING_COLLISION);
			});
		}
		
		private function dispatchCollisionEvents(arbiter:Arbiter, eventType:String):void
		{
			if ( arbiter.isCollisionArbiter() )
			{
				var spatial1:NapeSpatialComponent = arbiter.body1.userData.spatial;
				var spatial2:NapeSpatialComponent = arbiter.body2.userData.spatial;
				var ce:CollisionEvent = new CollisionEvent(eventType, spatial1, spatial2, new Point(arbiter.collisionArbiter.normal.x*scale, arbiter.collisionArbiter.normal.y*scale), arbiter.collisionArbiter.contacts);
				//Logger.debug(this, "dispatchCollisionEvents", "Dispatching " + eventType + " normal " + ce.normal.toString());
				if ( spatial1.owner )
					spatial1.owner.eventDispatcher.dispatchEvent(ce);
				if ( spatial2.owner )
					spatial2.owner.eventDispatcher.dispatchEvent(ce.clone());
			}
		}
		
		protected var _scale:Number = 30;
		protected var _space:Space;
		protected var _shapeDebug:ShapeDebug;
		protected var _gravity:Point = new Point(0, 9.8);
		protected var _otherItems:BasicSpatialManager2D = new BasicSpatialManager2D();
		protected var _materialManager:NapeMaterialManager;
		protected var _allowSleep : Boolean = true;
		protected var _worldBounds:Rectangle = new Rectangle(-5000, -5000, 10000, 10000);
		
		private var _visualDebugging:Boolean = false;
		private var _visualDebuggingPending:Boolean = false;
		private var _bodyCallbackType:CbType;
		
	}
}